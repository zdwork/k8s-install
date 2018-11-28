#!/bin/bash
source ./conf/master-install.conf
cat > ./test/kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
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
        "O": "system:kube-scheduler",
        "OU": "zdwork"
      }
    ]
}
EOF

sed -i '5 i\ \ \ \ \ \ "'`echo ${node_ip} |  cut -d " " -f 1`'"' ./test/kube-scheduler-csr.json
for ((i=2; $i<=${node}; i++))
do
  sed -i '5 i\ \ \ \ \ \ "'`echo ${node_ip} |  cut -d " " -f $i`'",' ./test/kube-scheduler-csr.json
done

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cd ..
for ip in $node_ip
do
  ssh root@${ip} "test -e ${kubernetes_ca}/scheduler_cert || mkdir -p ${kubernetes_ca}/scheduler_cert"
  scp ./test/kube-scheduler* root@${ip}:${kubernetes_ca}/scheduler_cert
done


${k8s_install_dir}/bin/kubectl config set-cluster kubernetes \
  --certificate-authority=${kubernetes_ca}/cert/ca.pem \
  --embed-certs=true \
  --server=${apiserver} \
  --kubeconfig=./test/kube-scheduler.kubeconfig

${k8s_install_dir}/bin/kubectl config set-credentials system:kube-scheduler \
  --client-certificate=${kubernetes_ca}/scheduler_cert/kube-scheduler.pem \
  --client-key=${kubernetes_ca}/scheduler_cert/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=./test/kube-scheduler.kubeconfig

${k8s_install_dir}/bin/kubectl config set-context system:kube-scheduler \
  --cluster=kubernetes \
  --user=system:kube-scheduler \
  --kubeconfig=./test/kube-scheduler.kubeconfig

${k8s_install_dir}/bin/kubectl config use-context system:kube-scheduler --kubeconfig=./test/kube-scheduler.kubeconfig

for ip in ${node_ip}
do
  scp ./test/kube-scheduler.kubeconfig root@${ip}:${k8s_install_dir}/scheduler/conf
done

cat > ./test/kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${k8s_install_dir}/scheduler/WorkDir
ExecStart=${k8s_install_dir}/bin/kube-scheduler \\
  --address=127.0.0.1 \\
  --kubeconfig=${k8s_install_dir}/scheduler/conf/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --logtostderr=false \\
  --alsologtostderr=true \\
  --log-dir=${k8s_install_dir}/scheduler/WorkDir/log \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#start
for ip in ${node_ip}
do
  scp ./test/kube-scheduler.service root@${ip}:/etc/systemd/system/
  ssh root@${ip} "systemctl daemon-reload && systemctl enable kube-scheduler && systemctl start kube-scheduler"
done

for ip in $node_ip
do
  ssh root@${ip} "systemctl restart kube-scheduler"
done

#check
sleep 10
for ip in ${node_ip}
do
  ssh root@${ip} "systemctl status kube-scheduler | grep 'Active:'"
done

curl -s http://127.0.0.1:10251/metrics | head -20
