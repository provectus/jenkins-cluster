#! /bin/bash
# configure Jenkins and EFS
mkdir ${JENKINS_HOME}
echo "${EFS_ENDPOINT}:/ ${JENKINS_HOME} nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab
mount ${JENKINS_HOME}
[ "$(ls -A ${JENKINS_HOME}/)" ] && cp -a /var/lib/jenkins/* ${JENKINS_HOME}/
chown -R jenkins. ${JENKINS_HOME}
sed -i 's|^JENKINS_HOME=.*|JENKINS_HOME=${JENKINS_HOME}|g' /etc/{default,sysconfig}/jenkins ||:
service jenkins restart

# configure Corosync+Pacemaker
export NODELIST="${NODELIST}"
export CLUSTER_SIZE="${CLUSTER_SIZE}"
envsubst < /etc/corosync/corosync.conf.tpl > /etc/corosync/corosync.conf
systemctl restart corosync pacemaker

pcs property set stonith-enabled=false
pcs resource create elastic-ip ocf:heartbeat:awseip elastic_ip="${ELASTIC_IP}" awscli="$(which aws)" allocation_id="${ELASTIC_IP_ALLOCATION}" op start   timeout="10s" interval="0s" on-fail="restart" op monitor timeout="10s" interval="1s" on-fail="restart" op stop timeout="10s" interval="0s" on-fail="block" meta migration-threshold="2" failure-timeout="10s" resource-stickiness="100" --group jenkins-master
pcs resource create jenkins ocf:heartbeat:jenkins op start   timeout="10s" interval="0s" on-fail="restart" op monitor timeout="10s" interval="1s" on-fail="restart" op stop timeout="10s" interval="0s" on-fail="block" meta migration-threshold="2" failure-timeout="10s" resource-stickiness="100" --group jenkins-master
