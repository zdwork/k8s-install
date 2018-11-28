#!/bin/bash
clear

source ./conf/node-install.conf
echo -e "\033[1;33m ---------------- flanneld --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status flanneld | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- docker --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status docker | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- kubelet --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status kubelet | grep 'Active:'"
done

echo -e "\033[1;33m ---------------- kube-proxy --------------------------------\033[0m"
for ip in ${node_ip}
do
  echo -e "${ip}::\c";ssh root@${ip} "hostname"
  ssh root@${ip} "systemctl status kube-proxy | grep 'Active:'"
done
