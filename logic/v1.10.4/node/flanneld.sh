#!/bin/bash
source ./conf/master-install.conf
source ./conf/node-install.conf

for ip in ${node_ip}
do
  ssh root@${ip} "test -e ${kubernetes_ca}/flanneld_cert/ || mkdir -p ${kubernetes_ca}/flanneld_cert/"
  scp ${kubernetes_ca}/flanneld_cert/* root@${ip}:${kubernetes_ca}/flanneld_cert
done

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

#check
for ip in ${node_ip}
do
  ssh root@${ip} "systemctl status flanneld | grep 'Active:'"
done
