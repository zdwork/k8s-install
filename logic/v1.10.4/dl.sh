#!/bin/bash
yum -y install wget

#client dl
while true
do
sleep 2
test -e ./source/kubernetes-client-linux-amd64.tar.gz
  if [[ $? != 0 ]]; then
    wget -P ./source/ https://dl.k8s.io/v1.10.4/kubernetes-client-linux-amd64.tar.gz
  else
    client="`sha256sum ./source/kubernetes-client-linux-amd64.tar.gz | cut -d " " -f 1`"
    if [[ $client == "2831fe621bf1542a1eac38b8f50aa40a96b26153e850b3ff7155e5ce4f4f400e" ]]; then
      break
    else
      rm -rf ./source/kubernetes-client-linux-amd64.tar.gz
      wget -P ./source/ https://dl.k8s.io/v1.10.4/kubernetes-client-linux-amd64.tar.gz
    fi
  fi
done

#server dl
while true
do
sleep 2
test -e ./source/kubernetes-server-linux-amd64.tar.gz
  if [[ $? != 0 ]]; then
    wget -P ./source/ https://dl.k8s.io/v1.10.4/kubernetes-server-linux-amd64.tar.gz
  else
    client="`sha256sum ./source/kubernetes-server-linux-amd64.tar.gz | cut -d " " -f 1`"
    if [[ $client == "e2381459ba91674b5e5cc10c8e8d6dc910e71874d01165ca07a94188edc8505e" ]]; then
      break
    else
      rm -rf ./source/kubernetes-server-linux-amd64.tar.gz
      wget -P ./source/ https://dl.k8s.io/v1.10.4/kubernetes-server-linux-amd64.tar.gz
    fi
  fi
done

#docker dl
while true
do
sleep 2
test -e ./source/docker-18.03.1-ce.tgz
  if [[ $? != 0 ]]; then
    wget -P ./source/ https://download.docker.com/linux/static/stable/x86_64/docker-18.03.1-ce.tgz
  else
    client="`sha256sum ./source/docker-18.03.1-ce.tgz | cut -d " " -f 1`"
    if [[ $client == "0e245c42de8a21799ab11179a4fce43b494ce173a8a2d6567ea6825d6c5265aa" ]]; then
      break
    else
      rm -rf ./source/docker-18.03.1-ce.tgz
      wget -P ./source/ https://download.docker.com/linux/static/stable/x86_64/docker-18.03.1-ce.tgz
    fi
  fi
done
