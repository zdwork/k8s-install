#!/bin/bash
source ./conf/master-install.conf
cat > ./test/kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
    ],
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-controller-manager",
        "OU": "zdwork"
      }
    ]
}
EOF


sed -i '9 i\ \ \ \ \ \ "'`echo ${node_ip} |  cut -d " " -f 1`'"' ./test/kube-controller-manager-csr.json
for ((i=2; $i<=${node}; i++))
do
  sed -i '9 i\ \ \ \ \ \ "'`echo ${node_ip} |  cut -d " " -f $i`'",' ./test/kube-controller-manager-csr.json
done

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
cd ..
for ip in $node_ip
do
  ssh root@${ip} "test -e ${kubernetes_ca}/controllerManager_cert || mkdir -p ${kubernetes_ca}/controllerManager_cert"
  scp ./test/kube-controller-manager* root@${ip}:${kubernetes_ca}/controllerManager_cert
done

${k8s_install_dir}/bin/kubectl config set-cluster kubernetes \
  --certificate-authority=${kubernetes_ca}/cert/ca.pem \
  --embed-certs=true \
  --server=${apiserver} \
  --kubeconfig=./test/kube-controller-manager.kubeconfig

${k8s_install_dir}/bin/kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=${kubernetes_ca}/controllerManager_cert/kube-controller-manager.pem \
  --client-key=${kubernetes_ca}/controllerManager_cert/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=./test/kube-controller-manager.kubeconfig

${k8s_install_dir}/bin/kubectl config set-context system:kube-controller-manager \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=./test/kube-controller-manager.kubeconfig

${k8s_install_dir}/bin/kubectl config use-context system:kube-controller-manager --kubeconfig=./test/kube-controller-manager.kubeconfig

for ip in $node_ip
do
  scp ./test/kube-controller-manager.kubeconfig root@${ip}:${k8s_install_dir}/controllerManager/conf
done

cat > ./test/kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${k8s_install_dir}/controllerManager/WorkDir
ExecStart=${k8s_install_dir}/bin/kube-controller-manager \\
  --kubeconfig=${k8s_install_dir}/controllerManager/conf/kube-controller-manager.kubeconfig \\
  --service-cluster-ip-range=${svc_cidr} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=${kubernetes_ca}/cert/ca.pem \\
  --cluster-signing-key-file=${kubernetes_ca}/cert/ca-key.pem \\
  --experimental-cluster-signing-duration=8760h \\
  --root-ca-file=${kubernetes_ca}/cert/ca.pem \\
  --service-account-private-key-file=${kubernetes_ca}/cert/ca-key.pem \\
  --leader-elect=true \\
  --feature-gates=RotateKubeletServerCertificate=true \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --horizontal-pod-autoscaler-use-rest-clients=true \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --tls-cert-file=${kubernetes_ca}/controllerManager_cert/kube-controller-manager.pem \\
  --tls-private-key-file=${kubernetes_ca}/controllerManager_cert/kube-controller-manager-key.pem \\
  --use-service-account-credentials=true \\
  --logtostderr=false \\
  --alsologtostderr=true \\
  --log-dir=${k8s_install_dir}/controllerManager/WorkDir/log \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#start
for ip in ${node_ip}
do
  scp ./test/kube-controller-manager.service root@${ip}:/etc/systemd/system/
  ssh root@${ip} "systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl start kube-controller-manager"
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl restart kube-controller-manager"
done

#check
for ip in ${node_ip}
do
   ssh root@${ip} "systemctl status kube-controller-manager|grep Active"
done

sleep 10
curl -s --cacert ${kubernetes_ca}/cert/ca.pem https://127.0.0.1:10252/metrics
