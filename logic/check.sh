#!/bin/bash
clear

source ./conf/master-install.conf
echo -e "\033[1;33m ---------------- etcd --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status etcd | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- kube-apiserver -----------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status  kube-apiserver | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- kube-scheduler ------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status  kube-scheduler | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- kube-controller_manager ----------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status  kube-controller-manager | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- keepalived ------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status keepalived | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- haproxy ---------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status haproxy | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- flanneld --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status flanneld | grep 'Active:'"
done

echo -e "\033[1;33m ################ Current cluster state ####################\033[0m"
${k8s_install_dir}/bin/kubectl get cs
