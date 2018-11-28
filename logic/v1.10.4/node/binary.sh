#!/bin/sh
source ./conf/master-install.conf
source ./conf/node-install.conf

tar -xzvf ./source/flannel-v0.10.0-linux-amd64.tar.gz -C ./source/flannel
#tar -xvf ./source/docker-18.06.0-ce.tgz
tar -xvf ./source/docker-18.03.1-ce.tgz

for ip in ${node_ip}
do
  #rootCA
  ssh root@${ip} "test -e ${kubernetes_ca}/cert || mkdir -p ${kubernetes_ca}/cert"
  scp ${kubernetes_ca}/cert/ca.pem root@${ip}:${kubernetes_ca}/cert/

  #create k8s bin
  ssh root@${ip} "test -e ${k8s_install_dir}/bin || mkdir -p ${k8s_install_dir}/bin"

  #flannel install  
  scp ./source/flannel/{flanneld,mk-docker-opts.sh} root@${ip}:${k8s_install_dir}/bin
  
  #docker install
  ssh root@${ip} "test -e ${k8s_install_dir}/docker/WorkDir || mkdir -p ${k8s_install_dir}/docker/WorkDir"
  scp ./docker/docker*  root@${ip}:${k8s_install_dir}/bin

  #kubelet install
  ssh root@${ip} "test -e ${k8s_install_dir}/kubelet/bootstrap || mkdir -p ${k8s_install_dir}/kubelet/bootstrap"
  ssh root@${ip} "test -e ${k8s_install_dir}/kubelet/WorkDir/log || mkdir -p ${k8s_install_dir}/kubelet/WorkDir/log"
  ssh root@${ip} "test -e ${kubernetes_ca}/kubelet_cert || mkdir -p ${kubernetes_ca}/kubelet_cert"
  ssh root@${ip} "test -e ${k8s_install_dir}/kubelet/conf || mkdir -p ${k8s_install_dir}/kubelet/conf"
  scp ./kubernetes/server/bin/* root@${ip}:${k8s_install_dir}/bin
 
  #kube-proxy install
  ssh root@${ip} "test -e ${k8s_install_dir}/kube-proxy/conf || mkdir -p ${k8s_install_dir}/kube-proxy/conf"
  ssh root@${ip} "test -e ${k8s_install_dir}/kube-proxy/WorkDir/log || mkdir -p ${k8s_install_dir}/kube-proxy/WorkDir/log"
  #PATH
  ssh root@${ip} "chmod +x ${k8s_install_dir}/bin/*"
  ssh root@${ip} "echo PATH=/usr/local/k8s/bin/:$PATH >> /etc/profile"
  ssh root@${ip} "bash -c 'source /etc/profile'"
done

#delete
rm -rf ./source/flannel/*
rm -rf ./docker
