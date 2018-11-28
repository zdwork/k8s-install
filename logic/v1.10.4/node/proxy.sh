#!/bin/bash
source ./conf/master-install.conf
source ./conf/node-install.conf

cat > ./test/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
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

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
cd ..

${k8s_install_dir}/bin/kubectl config set-cluster kubernetes \
  --certificate-authority=${kubernetes_ca}/cert/ca.pem \
  --embed-certs=true \
  --server=${apiserver} \
  --kubeconfig=./test/kube-proxy.kubeconfig

${k8s_install_dir}/bin/kubectl config set-credentials kube-proxy \
  --client-certificate=./test/kube-proxy.pem \
  --client-key=./test/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=./test/kube-proxy.kubeconfig

${k8s_install_dir}/bin/kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=./test/kube-proxy.kubeconfig

${k8s_install_dir}/bin/kubectl config use-context default --kubeconfig=./test/kube-proxy.kubeconfig



for ip in ${node_ip}
do
  scp ./test/kube-proxy.kubeconfig root@${ip}:${k8s_install_dir}/kube-proxy/conf
done

cat > ./test/kube-proxy.config.yaml.template <<EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: ##node_ip##
clientConnection:
  kubeconfig: ${k8s_install_dir}/kube-proxy/conf/kube-proxy.kubeconfig
clusterCIDR: ${cluster_cidr}
healthzBindAddress: ##node_ip##:10256
hostnameOverride: ##node_name##
kind: KubeProxyConfiguration
metricsBindAddress: ##node_ip##:10249
mode: "ipvs"
EOF

for (( i=1; i <= ${node}; i++ ))
do 
  sed -e "s/##node_name##/`echo ${node_name} | cut -d " " -f $i`/" -e "s/##node_ip##/`echo ${node_ip} | cut -d " " -f $i`/" ./test/kube-proxy.config.yaml.template > ./test/kube-proxy-`echo ${node_name} | cut -d " " -f $i`.config.yaml
  scp ./test/kube-proxy-`echo ${node_name} | cut -d " " -f $i`.config.yaml root@`echo ${node_name} | cut -d " " -f $i`:${k8s_install_dir}/kube-proxy/conf/kube-proxy.config.yaml
done

cat > ./test/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${k8s_install_dir}/kube-proxy/WorkDir
ExecStart=${k8s_install_dir}/bin/kube-proxy \\
  --config=${k8s_install_dir}/kube-proxy/conf/kube-proxy.config.yaml \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=${k8s_install_dir}/kube-proxy/WorkDir/log \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


for ip in ${node_ip}
do 
  scp ./test/kube-proxy.service root@${ip}:/etc/systemd/system/
done

for ip in ${node_ip}
do 
  ssh root@${ip} "systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy" 
done
