#!/bin/bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$dir/config"

#Install docker-ce, docker-compose
apt-get update
apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce -y
apt-get install docker-compose -y

#Certs
mkdir $dir/certs # maybe load with folder
openssl genrsa -out $dir/certs/root.key 2048
openssl req -x509 -new\
        -key $dir/certs/root.key\
        -days 365\
        -out $dir/certs/root.crt\
        -subj '/C=UA/ST=Kharkiv/L=Kharkiv/O=NURE/OU=Mirantis/CN=rootCA'

openssl genrsa -out $dir/certs/web.key 2048
openssl req -new\
        -key $dir/certs/web.key\
        -nodes\
        -out $dir/certs/web.csr\
        -subj "/C=UA/ST=Kharkiv/L=Karkiv/O=NURE/OU=Mirantis/CN=$(hostname -f)"


openssl x509 -req -extfile <(printf "subjectAltName=IP:${EXTERNAL_IP},DNS:${HOST_NAME}") -days 365 -in $dir/certs/web.csr -CA $dir/certs/root.crt -CAkey $dir/certs/root.key -CAcreateserial -out $dir/certs/web.crt

cat $dir/certs/web.crt $dir/certs/root.crt > $dir/certs/web-bundle.crt

#Make directory for logs
mkdir -p $NGINX_LOG_DIR

#docker-compose file editing
echo "version: '2'
services:
  nginx:
    image: $NGINX_IMAGE
    ports:
     - "$NGINX_PORT:443"
    volumes:
     - $dir/etc:/etc/nginx/conf.d
     - $dir/certs:/etc/ssl/certs
     - $NGINX_LOG_DIR:/var/log/nginx
  apache:
    image: $APACHE_IMAGE" > $dir/docker-compose.yml

#UP
cd $dir
docker-compose up -d
