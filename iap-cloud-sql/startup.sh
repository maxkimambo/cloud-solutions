#!/bin/bash 
sudo apt-get update -y &&\
sudo apt-get install mysql-client -y &&\
cd /usr/local/bin &&\
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.7.0/cloud-sql-proxy.linux.amd64 &&\
chmod +x cloud-sql-proxy