#!/bin/bash
source ./conf/master-install.conf


cat > ./test/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "${apiserver_vip}",
    "${kubernetes_svc_ip}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "root",
      "OU": "zdwork"
    }
  ]
}
EOF

for ip in ${node_ip}
do
  sed -i '5 i\ \ \ \ "'${ip}'",' ./test/kubernetes-csr.json
done

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
cd ..

cat > ./test/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${encryption_config}
      - identity: {}
EOF

for ip in ${node_ip}
do
  scp ./test/encryption-config.yaml root@${ip}:${k8s_install_dir}/apiserver/EncryptionConfig
  ssh root@${ip} "test -e ${kubernetes_ca}/apiserver_cert || mkdir -p ${kubernetes_ca}/apiserver_cert"
  scp ./test/kubernetes* root@${ip}:${kubernetes_ca}/apiserver_cert
done


cat > ./test/k8s-apiserver.service.template <<EOF
[Unit]
Description=k8s APIServer
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${k8s_install_dir}/apiserver/WorkDir
ExecStart=${k8s_install_dir}/bin/kube-apiserver \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --anonymous-auth=false \\
  --experimental-encryption-provider-config=${k8s_install_dir}/apiserver/EncryptionConfig/encryption-config.yaml \\
  --advertise-address=##NODE_IP## \\
  --bind-address=##NODE_IP## \\
  --insecure-port=0 \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all \\
  --enable-bootstrap-token-auth \\
  --service-cluster-ip-range=${svc_cidr} \\
  --service-node-port-range=${node_port_range} \\
  --tls-cert-file=${kubernetes_ca}/apiserver_cert/kubernetes.pem \\
  --tls-private-key-file=${kubernetes_ca}/apiserver_cert/kubernetes-key.pem \\
  --client-ca-file=${kubernetes_ca}/cert/ca.pem \\
  --kubelet-client-certificate=${kubernetes_ca}/apiserver_cert/kubernetes.pem \\
  --kubelet-client-key=${kubernetes_ca}/apiserver_cert/kubernetes-key.pem \\
  --service-account-key-file=${kubernetes_ca}/cert/ca-key.pem \\
  --etcd-cafile=${kubernetes_ca}/cert/ca.pem \\
  --etcd-certfile=${kubernetes_ca}/apiserver_cert/kubernetes.pem \\
  --etcd-keyfile=${kubernetes_ca}/apiserver_cert/kubernetes-key.pem \\
  --etcd-servers=${etcd_endpoint} \\
  --enable-swagger-ui=true \\
  --allow-privileged=true \\
  --apiserver-count=${node} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=${k8s_install_dir}/apiserver/WorkDir/audit.log \\
  --event-ttl=168h \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=${k8s_install_dir}/apiserver/WorkDir/log \\
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

for (( i=1; i <= ${node} ; i++ ))
  do
    sed -e "s/##NODE_NAME##/`echo ${node_name} | cut -d " " -f $i`/" -e "s/##NODE_IP##/`echo ${node_ip} | cut -d " " -f $i`/" ./test/k8s-apiserver.service.template > ./test/k8s-apiserver-`echo ${node_ip} | cut -d " " -f $i`.service
done

for ip in ${node_ip}
  do
    ssh root@${ip} "test -e /var/log/kubernetes || mkdir -p /var/log/kubernetes"
    scp ./test/k8s-apiserver-${ip}.service root@${ip}:/etc/systemd/system/kube-apiserver.service
done

for ip in ${node_ip}
  do
    ssh root@${ip} "systemctl daemon-reload && systemctl enable kube-apiserver && systemctl start kube-apiserver"
done

sleep 10

for ip in ${node_ip}
  do
    ssh root@${ip} "systemctl status  kube-apiserver | grep 'Active:'"
done

${k8s_install_dir}/bin/kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes

# test
ETCDCTL_API=3 ${k8s_install_dir}/bin/etcdctl \
    --endpoints=${etcd_endpoint} \
    --cacert=${kubernetes_ca}/cert/ca.pem \
    --cert=${kubernetes_ca}/etcd_cert/etcd.pem \
    --key=${kubernetes_ca}/etcd_cert/etcd-key.pem \
    get /registry/ --prefix --keys-only

${k8s_install_dir}/bin/kubectl get componentstatuses
