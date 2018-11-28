#!/bin/bash
source ./conf/master-install.conf
masterIP=`echo ${node_ip} | cut -d " " -f 1`
cat  > ./test/keepalived-${masterIP}-master.conf <<EOF
global_defs {
    router_id master-${masterIP}
    enable_script_security
}

vrrp_script check-haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 5
    weight -30
    user root
}

vrrp_instance k8s {
    state MASTER
    priority 120
    dont_track_primary
    interface ${vip_interface}
    virtual_router_id 88
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        ${apiserver_vip}
    }
}
EOF

for ip in ${node_ip}
do
  ssh root@${ip} "yum install -y keepalived psmisc"
  ssh root@${ip} "test -e /etc/keepalived/ || mkdir -p /etc/keepalived/"
done

systemctl daemon-reload && systemctl enable keepalived && systemctl restart keepalived
scp ./test/keepalived-${masterIP}-master.conf root@${masterIP}:/etc/keepalived/keepalived.conf


for (( i=2; i <= ${node}; i++ ))
do
cat  > ./test/keepalived-`echo ${node_ip} | cut -d " " -f $i`-backup.conf <<EOF
global_defs {
    router_id backup-`echo ${node_ip} | cut -d " " -f $i`
    enable_script_security
}

vrrp_script check-haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 5
    weight -30
    user root
}

vrrp_instance k8s {
    state BACKUP
    priority 110
    dont_track_primary
    interface ${vip_interface}
    virtual_router_id 88
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        ${apiserver_vip}
    }
}
EOF
done

for (( i=2; i <= ${node}; i++ ))
do
  scp ./test/keepalived-`echo ${node_ip} | cut -d " " -f $i`-backup.conf root@`echo ${node_ip} | cut -d " " -f $i`:/etc/keepalived/keepalived.conf
  sleep 1
  ssh root@`echo ${node_ip} | cut -d " " -f $i` "systemctl daemon-reload;systemctl enable keepalived;systemctl restart keepalived"
done

for ip in ${node_ip}
do
  ssh root@${ip} "systemctl restart  keepalived"
done

for ip in ${node_ip}
do
  sleep 3
  ssh root@${ip} "systemctl status keepalived"
done

sleep 3

for ip in ${node_ip}
do
  echo "\n"
  echo -e "\033[33m --------->>>>>>> ${ip} PING VIP STATUS \033[0m"
  echo "\n"
  ssh root@${ip} "ping -c 2 ${apiserver_vip}"
done


