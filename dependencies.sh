#!/bin/bash

BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing Maven.${NC}"
curl -LO https://apache.claz.org/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz && \
tar xzvf apache-maven-3.6.3-bin.tar.gz && \
rm apache-maven-3.6.3-bin.tar.gz && \
mv apache-maven-3.6.3 /usr/local/apache-maven-3.6.3

echo -e "${BLUE}Installing Docker Client.${NC}"
apt-get update && \
apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common && \
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable" && \
apt-get update && \
apt-get -y install docker-ce
usermod -a -G docker jenkins

echo -e "${BLUE}Installing pip3 and awscli.${NC}"
apt update -y
apt install python3-pip -y
pip3 install awscli

echo -e "${BLUE}Installing Nodejs${NC}"
curl -sL https://deb.nodesource.com/setup_12.x | bash
apt install nodejs -y
node --version

echo -e "${BLUE}Finished installing dependencies.${NC}"
