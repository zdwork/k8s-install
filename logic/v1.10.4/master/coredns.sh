#!/bin/bash
source ./conf/master-install.conf
tar zvxf ./kubernetes/kubernetes-src.tar.gz -C ./kubernetes/
cp ./kubernetes/cluster/addons/dns/coredns.yaml.base ./test/coredns.yaml
sed -i "s/kubernetes __PILLAR__DNS__DOMAIN__ in-addr.arpa ip6.arpa {/kubernetes ${cluster_dns_domain}. in-addr.arpa ip6.arpa {/g" test/coredns.yaml
sed -i "s/__PILLAR__DNS__SERVER__/${kubernetes_dns_ip}/g" ./test/coredns.yaml
sed -i "s/coredns\/coredns:1.0.6/zdwork\/coredns:1.0.6/g" ./test/coredns.yaml
${k8s_install_dir}/bin/kubectl apply -f ./test/coredns.yaml
