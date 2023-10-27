#!/bin/bash 
sudo apt-get update -y &&\
sudo apt-get install curl -y &&\
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install vault -y
mkdir -p /etc/vault.d
# echo the following config into /etc/vault.d/vault.hcl

echo <<EOF
storage "raft" {
  path    = "./vault/data"
  node_id = "master"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

api_addr = "http://10.0.0.4:8200"
cluster_addr = "https://10.0.0.4:8201"
ui = true
EOF > /etc/vault.d/vault.hcl
