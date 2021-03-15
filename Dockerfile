FROM jenkins/jenkins:lts-jdk11

COPY dependencies.sh /dependencies.sh

USER root
RUN chmod +x /dependencies.sh
RUN /dependencies.sh
ENV M2_HOME=/usr/local/apache-maven-3.6.3
ENV M2=$M2_HOME/bin
ENV PATH=$PATH:$M2

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
