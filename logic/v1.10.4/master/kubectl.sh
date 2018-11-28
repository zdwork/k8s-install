#!/bin/bash
source ./conf/master-install.conf

cat > ./test/admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "zdwork"
    }
  ]
}
EOF

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes admin-csr.json | cfssljson -bare admin

for ip in ${node_ip}
do
  ssh root@${ip} "test -e ${kubernetes_ca}/kubectl_cert || mkdir -p ${kubernetes_ca}/kubectl_cert"
  scp ./admin* root@${ip}:${kubernetes_ca}/kubectl_cert
done

# Set cluster parameters
${k8s_install_dir}/bin/kubectl config set-cluster kubernetes \
  --certificate-authority=${kubernetes_ca}/cert/ca.pem \
  --embed-certs=true \
  --server=${apiserver} \
  --kubeconfig=kubectl.config

# Set client authentication parameters
${k8s_install_dir}/bin/kubectl config set-credentials admin \
  --client-certificate=${kubernetes_ca}/kubectl_cert/admin.pem \
  --client-key=${kubernetes_ca}/kubectl_cert/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubectl.config

# Set context parameters
${k8s_install_dir}/bin/kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.config
  
# Set context
${k8s_install_dir}/bin/kubectl config use-context kubernetes --kubeconfig=kubectl.config

for ip in ${node_ip}
do
  ssh root@${ip} "test -e ~/.kube/ || mkdir -p ~/.kube/"
  scp ./kubectl.config root@${ip}:~/.kube/config
done
cd ..
