#!/bin/bash
source ./conf/node-install.conf
yum -y install expect wget

auto_login_ssh () {
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof         {exit 1;}
                }
                "
    return $?
}

# create .ssh
i=0
for ip in ${node_ip}
do
let i++
  auto_login_ssh `echo ${node_pass} | cut -d " " -f $i` root@${ip} "test -e /root/.ssh && test -e /root/.ssh || mkdir /root/.ssh"
done

# key
#ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

# config key login
i=0
for ip in ${node_ip}
do
let i++
  ./logic/expect_scp ${ip} root `echo ${node_pass} | cut -d " " -f $i` ~/.ssh/id_rsa.pub /root/.ssh/authorized_keys
  echo -e "\n---Exit Status: $?"
done

# Set system parameters
cat > ./test/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
EOF

# install
i=0
for ip in ${node_ip}
do
let i++
  ssh root@${ip} "hostnamectl set-hostname `echo $node_name | cut -d " " -f $i`"
  ssh root@${ip} "systemctl stop firewalld;systemctl disable firewalld"
  ssh root@${ip} "iptables -F && sudo iptables -X && sudo iptables -F -t nat && sudo iptables -X -t nat && iptables -P FORWARD ACCEPT"
  ssh root@${ip} "swapoff -a;sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab;setenforce 0"
  ssh root@${ip} "sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config"
  ssh root@${ip} "service dnsmasq stop;systemctl disable dnsmasq;systemctl stop dnsmasq"
  ssh root@${ip} "yum clean all"
  ssh root@${ip} "rm -rf /var/cache/yum"
  ssh root@${ip} "yum makecache fast -y"
  ssh root@${ip} "yum -y install epel-release || yum -y install epel-release"
  scp ./test/kubernetes.conf root@$ip:/etc/sysctl.d/kubernetes.conf
  ssh root@${ip} "mount -t cgroup -o cpu,cpuacct none /sys/fs/cgroup/cpu,cpuacct"
  ssh root@${ip} "timedatectl set-timezone Asia/Shanghai"
  ssh root@${ip} "timedatectl set-local-rtc 0"
  ssh root@${ip} "systemctl restart rsyslog"
  ssh root@${ip} "systemctl restart crond"
  ssh root@${ip} "sysctl -p /etc/sysctl.d/kubernetes.conf"
done
for ip in ${node_ip}
do
   ssh root@${ip} "yum install -y conntrack ipvsadm ipset jq iptables curl sysstat libseccomp && /usr/sbin/modprobe ip_vs || yum install -y conntrack ipvsadm ipset jq iptables curl sysstat libseccomp && /usr/sbin/modprobe ip_vs"
done
for ip in ${node_ip}
do
  ssh root@${ip} "modprobe br_netfilter"
  ssh root@${ip} "modprobe ip_vs"
done

# Set hosts
i=0
for ip in ${node_ip}
do
let i++
  echo "${ip} `echo ${node_name} | cut -d " " -f $i`" >> /etc/hosts
done

#copy to master
source ./conf/master-install.conf
for ip in ${node_ip}
do
  scp /etc/hosts root@${ip}:/etc/hosts
done

#copy to node
source ./conf/node-install.conf
for ip in ${node_ip}
do
  scp /etc/hosts root@${ip}:/etc/hosts
done
