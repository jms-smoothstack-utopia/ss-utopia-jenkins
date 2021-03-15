#!/bin/bash

apt-get update && apt update
apt install git -y

# install and set docker configuration
apt install -y docker-compose
groupadd docker
gpasswd -a ubuntu docker

# get docker ready
docker pull jenkins/jenkins:lts-jdk11
docker pull sonarqube:lts

# create volume folders
mkdir -p /home/ubuntu/jenkins/data
mkdir -p /home/ubuntu/sonarqube

# get and build docker image/compose file
mkdir -p /home/ubuntu/docker_files
git clone --depth 1 https://github.com/jms-smoothstack-utopia/ss-utopia-jenkins /home/ubuntu/docker_files
docker build -t ss-utopia/jenkins --rm /home/ubuntu/docker_files

touch /usr/local/bin/start-jenkins
cat > /usr/local/bin/start-jenkins << 'EOF'
#!/bin/sh

docker-compose -f /home/ubuntu/docker_files/docker-compose.yaml up -d
EOF

chmod +x /usr/local/bin/start-jenkins

touch /etc/systemd/system/jenkins.service

chmod 664 /etc/systemd/system/jenkins.service

cat > /etc/systemd/system/jenkins.service << 'EOF'
[UNIT]
Description=Start Jenkins and Sonarqube with docker-compose

[Service]
ExecStart=/usr/local/bin/start-jenkins

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins
