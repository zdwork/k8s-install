#!/bin/bash
source ./conf/master-install.conf
source ./conf/node-install.conf
# bootstrap kubeconfig

for name in ${node_name}
  do
    # create token
    export bootstrap_token=$(${k8s_install_dir}/bin/kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${name} \
      --kubeconfig ~/.kube/config)

    # Setting cluster parameters
    ${k8s_install_dir}/bin/kubectl config set-cluster kubernetes \
      --certificate-authority=${kubernetes_ca}/cert/ca.pem \
      --embed-certs=true \
      --server=${apiserver} \
      --kubeconfig=./test/kubelet-bootstrap-${name}.kubeconfig

    # Set client authentication parameters
    ${k8s_install_dir}/bin/kubectl config set-credentials kubelet-bootstrap \
      --token=${bootstrap_token} \
      --kubeconfig=./test/kubelet-bootstrap-${name}.kubeconfig

    # Setting context parameters
    ${k8s_install_dir}/bin/kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=./test/kubelet-bootstrap-${name}.kubeconfig

    # Setting the default context
    ${k8s_install_dir}/bin/kubectl config use-context default --kubeconfig=./test/kubelet-bootstrap-${name}.kubeconfig
done


for name in ${node_name}
do
  scp -o "StrictHostKeyChecking no" ./test/kubelet-bootstrap-${name}.kubeconfig root@${name}:${k8s_install_dir}/kubelet/bootstrap/kubelet-bootstrap.kubeconfig
done

cat > ./test/kubelet.config.json.template <<EOF
{
  "kind": "KubeletConfiguration",
  "apiVersion": "kubelet.config.k8s.io/v1beta1",
  "address": "##node_ip##",
  "port": 10250,
  "readOnlyPort": 0,
  "rotateCertificates": true,
  "serverTLSBootstrap": true,
  "authentication": {
    "x509": {
      "clientCAFile": "${kubernetes_ca}/cert/ca.pem"
    },
    "webhook": {
      "enabled": true,
      "cacheTTL": "2m0s"
    },
    "anonymous": {
      "enabled": false
    }
  },
  "authorization": {
    "mode": "Webhook",
    "webhook": {
      "cacheAuthorizedTTL": "5m0s",
      "cacheUnauthorizedTTL": "30s"
    }
  },
  "cgroupDriver": "cgroupfs",
  "hairpinMode": "promiscuous-bridge",
  "maxPods": 2000,
  "serializeImagePulls": false,
  "featureGates": {
    "RotateKubeletClientCertificate": true,
    "RotateKubeletServerCertificate": true
  },
  "clusterDomain": "${cluster_dns_domain}",
  "clusterDNS": ["${kubernetes_dns_ip}"]
}
EOF


for ip in ${node_ip}
do
  sed -e "s/##node_ip##/${ip}/" ./test/kubelet.config.json.template > ./test/kubelet.config-${ip}.json
  scp ./test/kubelet.config-${ip}.json root@${ip}:${k8s_install_dir}/kubelet/conf/kubelet.config.json
done

# kubelet systemd unit
cat > ./test/kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=${k8s_install_dir}/kubelet/WorkDir
ExecStart=${k8s_install_dir}/bin/kubelet \\
  --root-dir=${k8s_install_dir}/kubelet/WorkDir \\
  --bootstrap-kubeconfig=${k8s_install_dir}/kubelet/bootstrap/kubelet-bootstrap.kubeconfig \\
  --cert-dir=${kubernetes_ca}/kubelet_cert \\
  --kubeconfig=${k8s_install_dir}/kubelet/conf/kubelet.kubeconfig \\
  --config=${k8s_install_dir}/kubelet/conf/kubelet.config.json \\
  --hostname-override=##node_name## \\
  --pod-infra-container-image=zdwork/pod-infrastructure:latest \\
  --allow-privileged=true \\
  --logtostderr=false \\
  --alsologtostderr=true \\
  --log-dir=${k8s_install_dir}/kubelet/WorkDir/log \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

for name in ${node_name}
do
  sed -e "s/##node_name##/${name}/" ./test/kubelet.service.template > ./test/kubelet-${name}.service
  scp ./test/kubelet-${name}.service root@${name}:/etc/systemd/system/kubelet.service
done

${k8s_install_dir}/bin/kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers


for ip in ${node_ip}
do
  ssh root@${ip} "/usr/sbin/swapoff -a"
  ssh root@${ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl start kubelet"
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl status kubelet"
done

cat > ./test/csr-crb.yaml <<EOF
 # Approve all CSRs for the group "system:bootstrappers"
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: auto-approve-csrs-for-group
 subjects:
 - kind: Group
   name: system:bootstrappers
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
   apiGroup: rbac.authorization.k8s.io
---
 # To let a node of the group "system:nodes" renew its own credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-client-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
   apiGroup: rbac.authorization.k8s.io
---
# A ClusterRole which instructs the CSR approver to approve a node requesting a
# serving cert matching its client cert.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: approve-node-server-renewal-csr
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
---
 # To let a node of the group "system:nodes" renew its own server credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-server-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: approve-node-server-renewal-csr
   apiGroup: rbac.authorization.k8s.io
EOF

${k8s_install_dir}/bin/kubectl apply -f ./test/csr-crb.yaml

