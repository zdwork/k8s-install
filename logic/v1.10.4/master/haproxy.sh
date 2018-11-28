#!/bin/bash
source ./conf/master-install.conf

cat > ./test/haproxy.cfg <<EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /var/run/haproxy.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    nbproc 1

defaults
    log     global
    timeout connect 5000
    timeout client  10m
    timeout server  10m

listen  admin_stats
    bind 0.0.0.0:${haproxy_status_port}
    mode http
    log 127.0.0.1 local0 err
    stats refresh 30s
    stats uri /status
    stats realm welcome login\ Haproxy
    stats auth ${haproxy_name}:${haproxy_pass}
    stats hide-version
    stats admin if TRUE

listen kube-master
    bind 0.0.0.0:${apiserver_vip_port}
    mode tcp
    option tcplog
    balance source
EOF

for ip in ${node_ip}
do
  sed -i '$a\    server '${ip}' '${ip}':6443 check inter 2000 fall 2 rise 2 weight 1' ./test/haproxy.cfg
done

for ip in ${node_ip}
do
  ssh root@${ip} "yum install -y haproxy"
  ssh root@${ip} "test -e /etc/haproxy || mkdir -p /etc/haproxy"
  scp ./test/haproxy.cfg root@${ip}:/etc/haproxy
  ssh root@${ip} "systemctl daemon-reload;systemctl enable haproxy;systemctl start haproxy"
  ssh root@${ip} "systemctl restart haproxy"
done

