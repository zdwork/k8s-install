#!/bin/bash
source ./conf/master-install.conf
clear

MasterInstallV1_10() {
while :; do echo
  read -p "Do you want to install Master? [y/n]: " Master_yn
  if [[ ! $Master_yn =~ ^[y,n]$ ]]; then
    echo -e "\033[33m"input error! Please only input 'y' or 'n'"\033[0m"
  else
    if [[ $Master_yn == 'y' ]]; then
      master_install=1
      
      #Automatically approve CSR requests
      while :; do echo
        read -p "Do you want to automatically approve CSR requests? [y/n]: " CSR_yn
        if [[ ! $CSR_yn =~ ^[y,n]$ ]]; then
          echo -e "\033[33m"input error! Please only input 'y' or 'n'"\033[0m"
        else
          if [[ $CSR_yn == 'y' ]]; then
            CSR_install=1
            break
          else
            break
          fi
        fi
      done

      #install CorDns
      while :; do echo
        read -p "Whether to install the CoreDns plug-in? [y/n]: " CoreDns_yn
        if [[ ! $CoreDns_yn =~ ^[y,n]$ ]]; then
          echo -e "\033[33m"input error! Please only input 'y' or 'n'"\033[0m"
        else
          if [[ $CoreDns_yn == 'y' ]]; then
            coredns_install=1
            break 1
          else
            break 1
          fi
        fi
      done

        break
      else
        break
    fi
  fi
done
}

NodeInstallV1_10() {
while :; do echo
  read -p "Do you want to install node? [y/n]: " Node_yn
  if [[ ! $Node_yn =~ ^[y,n]$ ]]; then
    echo -e "\033[33m"input error! Please only input 'y' or 'n'"\033[0m"
  else
    if [[ $Node_yn == 'y' ]]; then
       node_install=1
       break
      else
        break
    fi
  fi
done
}

MasterVersion() {
echo -e "\033[1;36m    1. \033[0mINstall v1.10.4"
echo -e "\033[1;36m    2. \033[0mINstall v1.11.2"
read -p "Please input a number: " vst
  if [[ ! $vst =~ ^['1','2']$ ]]; then
    echo -e "\033[33m"input error! Please only input '1' or '2'"\033[0m"
  else
    if [[ $vst == '1' ]]; then
      MasterInstallV1_10
    fi
    if [[ $vst == '2' ]]; then
      #MasterInstallV1_11
      echo "No configuration"
    fi

  fi
}

NodeVersion() {
node_version=`${k8s_install_dir}/bin/kubectl version | grep ^Server | awk '{print $5}' | awk -F: '{print $2}' | sed 's/.$//'`
  if [[ $node_version == '"v1.10.4"' ]]; then
    NodeInstallV1_10
  fi
  if [[ $node_version == '"v1.11.2"' ]]; then
    NodeInstallV1_11
  fi

}

#select
echo "Welcome to use k8s installation script"
echo "  GitHub https://github.com/zdwork/k8s-install.git"

while :; do echo
echo "Please select the installation type:"
echo -e "\033[1;36m    1. \033[0mINstall Master"
echo -e "\033[1;36m    2. \033[0mINstall Node"
read -p "Please input a number: " st
  if [[ ! $st =~ ^['1','2']$ ]]; then
    echo -e "\033[33m"input error! Please only input '1' or '2'"\033[0m"
  else
    if [[ $st == '1' ]]; then
      MasterVersion
      break
    fi
    if [[ $st == '2' ]]; then
      NodeVersion
      break
    fi
  fi
done

if [[ $master_install == 1 ]]; then
  ./logic/v1.10.4/dl.sh
  ./logic/v1.10.4/master/init.sh
  ./logic/v1.10.4/master/binary.sh
  ./logic/v1.10.4/master/ca.sh
  ./logic/v1.10.4/master/etcd.sh
  ./logic/v1.10.4/master/kubectl.sh
  ./logic/v1.10.4/master/flanneld.sh
  ./logic/v1.10.4/master/haproxy.sh
  ./logic/v1.10.4/master/keepalived.sh
  ./logic/v1.10.4/master/apiserver.sh
  ./logic/v1.10.4/master/controller_manager.sh
  ./logic/v1.10.4/master/scheduler.sh
fi

if [[ $coredns_install == 1 ]]; then
  ./logic/v1.10.4/master/coredns.sh
fi

if [[ $CSR_install == 1 ]]; then
  ./logic/v1.10.4/master/Auto-approve-csr.sh
fi

if [[ $master_install == 1 ]]; then
  ./logic/check.sh
fi

if [[ $node_install == 1 ]]; then
  ./logic/v1.10.4/dl.sh
  ./logic/v1.10.4/node/init.sh
  ./logic/v1.10.4/node/binary.sh
  ./logic/v1.10.4/node/flanneld.sh
  ./logic/v1.10.4/node/docker.sh
  ./logic/v1.10.4/node/kubelet.sh
  ./logic/v1.10.4/node/proxy.sh
fi

if [[ $node_install == 1 ]]; then
  ./logic/check_node.sh
fi

