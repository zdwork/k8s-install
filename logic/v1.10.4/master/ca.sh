#!/bin/sh
source ./conf/master-install.conf

cp ./source/cfssl_linux-amd64 /usr/local/bin/cfssl
cp ./source/cfssljson_linux-amd64 /usr/local/bin/cfssljson
cp ./source/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
chmod +x /usr/local/bin/cfssl*

cat > ./test/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF

cat > ./test/ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "root",
      "OU": "zdwork"
    }
  ]
}
EOF
cd ./test
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cd ..
for ip in ${node_ip}
do
  ssh root@${ip} "test -e ${kubernetes_ca}/cert || mkdir -p ${kubernetes_ca}/cert"
  scp ./test/ca* root@${ip}:${kubernetes_ca}/cert
  
done
