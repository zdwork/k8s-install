#!/bin/bash
source ./conf/master-install.conf

cat > ./test/etcd-csr.json <<EOF
{
  "CN": "etcd",
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
      "O": "root",
      "OU": "zdwork"
    }
  ]
}
EOF

sed -i '5 i\ \ \ \ "'`echo ${node_ip} |  cut -d " " -f 1`'"' ./test/etcd-csr.json
for ((i=2; $i<=${node}; i++))
do
  sed -i '5 i\ \ \ \ "'`echo ${node_ip} |  cut -d " " -f $i`'",' ./test/etcd-csr.json
done

cd ./test
cfssl gencert -ca=${kubernetes_ca}/cert/ca.pem \
    -ca-key=${kubernetes_ca}/cert/ca-key.pem \
    -config=${kubernetes_ca}/cert/ca-config.json \
    -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

cd ..
for ip in ${node_ip}
do
  ssh root@${ip} "test -e ${kubernetes_ca}/etcd_cert || mkdir -p ${kubernetes_ca}/etcd_cert"
  scp ./test/etcd* root@${ip}:${kubernetes_ca}/etcd_cert
done

cat > ./test/etcd.service.template <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=${k8s_install_dir}/etcd/WorkDir
ExecStart=${k8s_install_dir}/bin/etcd \\
  --data-dir=${k8s_install_dir}/etcd/WorkDir \\
  --name=##node_name## \\
  --cert-file=${kubernetes_ca}/etcd_cert/etcd.pem \\
  --key-file=${kubernetes_ca}/etcd_cert/etcd-key.pem \\
  --trusted-ca-file=${kubernetes_ca}/cert/ca.pem \\
  --peer-cert-file=${kubernetes_ca}/etcd_cert/etcd.pem \\
  --peer-key-file=${kubernetes_ca}/etcd_cert/etcd-key.pem \\
  --peer-trusted-ca-file=${kubernetes_ca}/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://##node_ip##:2380 \\
  --initial-advertise-peer-urls=https://##node_ip##:2380 \\
  --listen-client-urls=https://##node_ip##:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls=https://##node_ip##:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${etcd_communication} \\
  --initial-cluster-state=new
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cd ./test
for (( i=1; i <= ${node}; i++ ))
  do
    sed -e "s/##node_name##/`echo ${node_name} | cut -d " " -f $i`/" -e "s/##node_ip##/`echo ${node_ip} | cut -d " " -f $i`/" etcd.service.template > etcd-`echo ${node_ip} | cut -d " " -f $i`.service 
done

for ip in ${node_ip}
do
  scp etcd-${ip}.service root@${ip}:/etc/systemd/system/etcd.service
  ssh root@${ip} "systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd &"
done

#restart
for ip in ${node_ip}
do
  sleep 20
  ssh root@${ip} "systemctl restart etcd"
done
cd ..

#check
sleep 20
for ip in ${node_ip}
  do
    ETCDCTL_API=3 ${k8s_install_dir}/bin/etcdctl \
    --endpoints=https://${ip}:2379 \
    --cacert=${kubernetes_ca}/cert/ca.pem \
    --cert=${kubernetes_ca}/etcd_cert/etcd.pem \
    --key=${kubernetes_ca}/etcd_cert/etcd-key.pem endpoint health >> ./log/etcd-install.log
  done
if [ $? == 0 ]
then
  echo "etcd install succeed"
else
  echo -e "\033[31m etcd install failed please chekc ./log/etcd-instal.log \033[0m" 
  exit
fi

