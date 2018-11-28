#!/bin/sh
source ./conf/master-install.conf

tar -xvf ./source/etcd-v3.3.9-linux-amd64.tar.gz
tar -xzvf ./source/kubernetes-client-linux-amd64.tar.gz -C ./source/k8s-client/
tar -xzvf ./source/flannel-v0.10.0-linux-amd64.tar.gz -C ./source/flannel
tar -xzvf ./source/kubernetes-server-linux-amd64.tar.gz

for ip in ${node_ip}
do
  #create k8s bin
  ssh root@$ip "test -e ${k8s_install_dir}/bin || mkdir -p ${k8s_install_dir}/bin"

  #etcd install
  ssh root@${ip} "test -e ${k8s_install_dir}/etcd/WorkDir || mkdir -p ${k8s_install_dir}/etcd/WorkDir"
  scp ./etcd-v3.3.9-linux-amd64/etcd* root@${ip}:${k8s_install_dir}/bin

  #kubectl install
  scp ./source/k8s-client/kubernetes/client/bin/kubectl root@${ip}:${k8s_install_dir}/bin
  
  #flannel install  
  scp ./source/flannel/{flanneld,mk-docker-opts.sh} root@${ip}:${k8s_install_dir}/bin
  
  #apiserver
  ssh root@${ip} "test -e ${k8s_install_dir}/apiserver/EncryptionConfig || mkdir -p ${k8s_install_dir}/apiserver/EncryptionConfig"
  ssh root@${ip} "test -e ${k8s_install_dir}/apiserver/WorkDir/log || mkdir -p ${k8s_install_dir}/apiserver/WorkDir/log"
  scp ./kubernetes/server/bin/* root@${ip}:${k8s_install_dir}/bin
  
  #controllerManager
  ssh root@${ip} "test -e ${k8s_install_dir}/controllerManager/conf || mkdir -p ${k8s_install_dir}/controllerManager/conf"
  ssh root@${ip} "test -e ${k8s_install_dir}/controllerManager/WorkDir/log || mkdir -p ${k8s_install_dir}/controllerManager/WorkDir/log"
  
  #scheduler
  ssh root@${ip} "test -e ${k8s_install_dir}/scheduler/conf || mkdir -p ${k8s_install_dir}/scheduler/conf"
  ssh root@${ip} "test -e ${k8s_install_dir}/scheduler/WorkDir/log || mkdir -p ${k8s_install_dir}/scheduler/WorkDir/log"  

  #PATH
  ssh root@${ip} "chmod +x ${k8s_install_dir}/bin/*"
  ssh root@${ip} "echo PATH=/usr/local/k8s/bin/:$PATH >> /etc/profile"
  ssh root@${ip} "bash -c 'source /etc/profile'"
done

rm -rf ./etcd-v3.3.9-linux-amd64
rm -rf ./source/k8s-client/*
rm -rf ./source/flannel/*
