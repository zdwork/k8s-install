#!/bin/bash
source ./conf/master-install.conf

cat > ./test/flanneld-csr.json <<EOF
{
  "CN": "flanneld",
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
    -profile=kubernetes etcd-csr.json | cfssljson -bare flanneld
cd ..
for ip in ${node_ip}
do
  ssh root@${ip} "test -e ${kubernetes_ca}/flanneld_cert || mkdir -p ${kubernetes_ca}/flanneld_cert"
  scp ./test/flanneld* root@${ip}:${kubernetes_ca}/flanneld_cert
done


${k8s_install_dir}/bin/etcdctl \
  --endpoints=${etcd_endpoint} \
  --ca-file=${kubernetes_ca}/cert/ca.pem \
  --cert-file=${kubernetes_ca}/flanneld_cert/flanneld.pem \
  --key-file=${kubernetes_ca}/flanneld_cert/flanneld-key.pem \
  set ${flanneld_etcd_prefix}/config '{"Network":"'${cluster_cidr}'", "SubnetLen": 21, "Backend": {"Type": "vxlan"}}'


cat > ./test/flanneld.service << EOF
[Unit]
Description=Flanneld etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=${k8s_install_dir}/bin/flanneld \\
  -etcd-cafile=${kubernetes_ca}/cert/ca.pem \\
  -etcd-certfile=${kubernetes_ca}/flanneld_cert/flanneld.pem \\
  -etcd-keyfile=${kubernetes_ca}/flanneld_cert/flanneld-key.pem \\
  -etcd-endpoints=${etcd_endpoint} \\
  -etcd-prefix=${flanneld_etcd_prefix} \\
  -iface=${flaneld_interface}
ExecStartPost=${k8s_install_dir}/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

for ip in ${node_ip}
do
  scp ./test/flanneld.service root@${ip}:/etc/systemd/system/
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl daemon-reload && systemctl enable flanneld && systemctl restart flanneld"
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl restart flanneld"
done

#check
sleep 5
${k8s_install_dir}/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --ca-file=${kubernetes_ca}/cert/ca.pem \
  --cert-file=${kubernetes_ca}/flanneld_cert/flanneld.pem \
  --key-file=${kubernetes_ca}/flanneld_cert/flanneld-key.pem \
  get ${flanneld_etcd_prefix}/config >> ./log/flanneld-cidr-msg.log

if [ $? == 0 ]
then
  echo "write flanneld in etcd succeed ./log/flanneld-cidr-msg.log"
else
  echo -e "\033[31m write flanneld in etcd succeed failed\033[0m" 
  exit
fi

