#!/bin/bash
source ./conf/master-install.conf
source ./conf/node-install.conf


cat > ./test/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com

[Service]
WorkingDirectory=${k8s_install_dir}/docker/WorkDir
Environment="PATH=${k8s_install_dir}/bin:/bin:/sbin:/usr/bin:/usr/sbin"
EnvironmentFile=-/run/flannel/docker
ExecStart=${k8s_install_dir}/bin/dockerd --log-level=error \$DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

for ip in ${node_ip}
do
  scp ./test/docker.service root@${ip}:/etc/systemd/system/
  ssh root@${ip} "/usr/sbin/iptables -F && /usr/sbin/iptables -X && /usr/sbin/iptables -F -t nat && /usr/sbin/iptables -X -t nat"
  ssh root@${ip} "/usr/sbin/iptables -P FORWARD ACCEPT"
  ssh root@${ip} "systemctl daemon-reload && systemctl enable docker && systemctl start docker"
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl status docker|grep Active"
done

for ip in ${node_ip}
do
  ssh root@${ip} "/usr/sbin/ip addr show flannel.1 && /usr/sbin/ip addr show docker0"
done
