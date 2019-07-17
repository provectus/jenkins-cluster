#! /bin/bash

wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install openjdk-8-jre ec2-instance-connect nfs-common unzip jq pacemaker corosync awscli crmsh pcs
apt-get -y install jenkins
mkdir -p /mnt/jenkins
echo "${efs_fqdn}:/ /mnt/jenkins nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab
mount -a
[ "$(ls -A /mnt/jenkins/)" ] && cp -rf /var/lib/jenkins/* /mnt/jenkins/
chown -R jenkins. /mnt/jenkins
sed -i 's|^JENKINS_HOME=.*|JENKINS_HOME=/mnt/jenkins|g' /etc/default/jenkins
sed -i 's|^JAVA_ARGS="|JAVA_ARGS="-Djenkins.install.runSetupWizard=false |g' /etc/default/jenkins
sed -i 's|^JENKINS_ARGS="|JENKINS_ARGS="--argumentsRealm.passwd.${user}=${password} --argumentsRealm.roles.${user}=admin |g' /etc/default/jenkins
service jenkins restart
export AWS_DEFAULT_REGION=$(curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
echo "AWS_DEFAULT_REGION=$${AWS_DEFAULT_REGION}" >> /etc/default/pacemaker
cat <<-EOF | base64 -d > /usr/lib/ocf/resource.d/heartbeat/jenkins
IyEvYmluL3NoCgo6ICR7T0NGX0ZVTkNUSU9OU19ESVI9JHtPQ0ZfUk9PVH0vbGliL2hlYXJ0YmVhdH0KLiAke09DRl9GVU5DVElPTlNfRElSfS9vY2Ytc2hlbGxmdW5jcwoKbWV0YV9kYXRhKCkgewogIGNhdCA8PEVORAo8P3htbCB2ZXJzaW9uPSIxLjAiPz4KPCFET0NUWVBFIHJlc291cmNlLWFnZW50IFNZU1RFTSAicmEtYXBpLTEuZHRkIj4KPHJlc291cmNlLWFnZW50IG5hbWU9IkplbmtpbnMiPgo8dmVyc2lvbj4xLjA8L3ZlcnNpb24+Cgo8bG9uZ2Rlc2MgbGFuZz0iZW4iPgpUaGlzIGlzIGEgSmVua2lucyBSZXNvdXJjZSBBZ2VudC4gSXQgZG9lcyBhYnNvbHV0ZWx5IG5vdGhpbmcgZXhjZXB0CmtlZXAgdHJhY2sgb2Ygd2hldGhlciBpdHMgcnVubmluZyBvciBub3QuCkl0cyBwdXJwb3NlIGluIGxpZmUgaXMgZm9yIHRlc3RpbmcgYW5kIHRvIHNlcnZlIGFzIGEgdGVtcGxhdGUgZm9yIFJBIHdyaXRlcnMuCgpOQjogUGxlYXNlIHBheSBhdHRlbnRpb24gdG8gdGhlIHRpbWVvdXRzIHNwZWNpZmllZCBpbiB0aGUgYWN0aW9ucwpzZWN0aW9uIGJlbG93LiBUaGV5IHNob3VsZCBiZSBtZWFuaW5nZnVsIGZvciB0aGUga2luZCBvZiByZXNvdXJjZQp0aGUgYWdlbnQgbWFuYWdlcy4gVGhleSBzaG91bGQgYmUgdGhlIG1pbmltdW0gYWR2aXNlZCB0aW1lb3V0cywKYnV0IHRoZXkgc2hvdWxkbid0L2Nhbm5vdCBjb3ZlciBfYWxsXyBwb3NzaWJsZSByZXNvdXJjZQppbnN0YW5jZXMuIFNvLCB0cnkgdG8gYmUgbmVpdGhlciBvdmVybHkgZ2VuZXJvdXMgbm9yIHRvbyBzdGluZ3ksCmJ1dCBtb2RlcmF0ZS4gVGhlIG1pbmltdW0gdGltZW91dHMgc2hvdWxkIG5ldmVyIGJlIGJlbG93IDEwIHNlY29uZHMuCjwvbG9uZ2Rlc2M+CjxzaG9ydGRlc2MgbGFuZz0iZW4iPkV4YW1wbGUgc3RhdGVsZXNzIHJlc291cmNlIGFnZW50PC9zaG9ydGRlc2M+Cgo8cGFyYW1ldGVycz4KPHBhcmFtZXRlciBuYW1lPSJzdGF0ZSIgdW5pcXVlPSIxIj4KPGxvbmdkZXNjIGxhbmc9ImVuIj4KTG9jYXRpb24gdG8gc3RvcmUgdGhlIHJlc291cmNlIHN0YXRlIGluLgo8L2xvbmdkZXNjPgo8c2hvcnRkZXNjIGxhbmc9ImVuIj5TdGF0ZSBmaWxlPC9zaG9ydGRlc2M+Cjxjb250ZW50IHR5cGU9InN0cmluZyIgZGVmYXVsdD0iJHtIQV9SU0NUTVB9L0plbmtpbnMtJHtPQ0ZfUkVTT1VSQ0VfSU5TVEFOQ0V9LnN0YXRlIiAvPgo8L3BhcmFtZXRlcj4KCjxwYXJhbWV0ZXIgbmFtZT0ibG9naW4iIHVuaXF1ZT0iMCI+Cjxsb25nZGVzYyBsYW5nPSJlbiI+CkEgYWRtaW4gdXNlciBuYW1lIGZvciBsb2NhbCBKZW5raW5zIGluc3RhbmNlCjwvbG9uZ2Rlc2M+CjxzaG9ydGRlc2MgbGFuZz0iZW4iPkEgYWRtaW4gdXNlciBuYW1lIGZvciBsb2NhbCBKZW5raW5zIGluc3RhbmNlPC9zaG9ydGRlc2M+Cjxjb250ZW50IHR5cGU9InN0cmluZyIgZGVmYXVsdD0iamVua2lucyIgLz4KPC9wYXJhbWV0ZXI+Cgo8cGFyYW1ldGVyIG5hbWU9InBhc3N3b3JkIiB1bmlxdWU9IjAiPgo8bG9uZ2Rlc2MgbGFuZz0iZW4iPgpBIGFkbWluIHVzZXIgcGFzc3dvcmQgZm9yIGxvY2FsIEplbmtpbnMgaW5zdGFuY2UKPC9sb25nZGVzYz4KPHNob3J0ZGVzYyBsYW5nPSJlbiI+QSBhZG1pbiB1c2VyIHBhc3N3b3JkIGZvciBsb2NhbCBKZW5raW5zIGluc3RhbmNlPC9zaG9ydGRlc2M+Cjxjb250ZW50IHR5cGU9InN0cmluZyIgZGVmYXVsdD0iamVua2lucyIgLz4KPC9wYXJhbWV0ZXI+Cgo8L3BhcmFtZXRlcnM+Cgo8YWN0aW9ucz4KPGFjdGlvbiBuYW1lPSJzdGFydCIgICAgICAgIHRpbWVvdXQ9IjIwIiAvPgo8YWN0aW9uIG5hbWU9InN0b3AiICAgICAgICAgdGltZW91dD0iMjAiIC8+CjxhY3Rpb24gbmFtZT0ibW9uaXRvciIgICAgICB0aW1lb3V0PSIyMCIgaW50ZXJ2YWw9IjEwIiBkZXB0aD0iMCIgLz4KPGFjdGlvbiBuYW1lPSJyZWxvYWQiICAgICAgIHRpbWVvdXQ9IjIwIiAvPgo8YWN0aW9uIG5hbWU9Im1pZ3JhdGVfdG8iICAgdGltZW91dD0iMjAiIC8+CjxhY3Rpb24gbmFtZT0ibWlncmF0ZV9mcm9tIiB0aW1lb3V0PSIyMCIgLz4KPGFjdGlvbiBuYW1lPSJtZXRhLWRhdGEiICAgIHRpbWVvdXQ9IjUiIC8+CjxhY3Rpb24gbmFtZT0idmFsaWRhdGUtYWxsIiAgIHRpbWVvdXQ9IjIwIiAvPgo8L2FjdGlvbnM+CjwvcmVzb3VyY2UtYWdlbnQ+CkVORAp9CgojIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIwoKamVua2luc191c2FnZSgpIHsKICBjYXQgPDxFTkQKdXNhZ2U6ICQwIHtzdGFydHxzdG9wfG1vbml0b3J8bWlncmF0ZV90b3xtaWdyYXRlX2Zyb218dmFsaWRhdGUtYWxsfG1ldGEtZGF0YX0KCkV4cGVjdHMgdG8gaGF2ZSBhIGZ1bGx5IHBvcHVsYXRlZCBPQ0YgUkEtY29tcGxpYW50IGVudmlyb25tZW50IHNldC4KRU5ECn0KCmplbmtpbnNfc3RhcnQoKSB7CiAgICBqZW5raW5zX21vbml0b3IKICAgIGphdmEgLWphciAvdmFyL2NhY2hlL2plbmtpbnMvd2FyL1dFQi1JTkYvamVua2lucy1jbGkuamFyIC1zIGh0dHA6Ly8xMjcuMC4wLjE6ODA4MCAtYXV0aCAke09DRl9SRVNLRVlfbG9naW59OiR7T0NGX1JFU0tFWV9wYXNzd29yZH0gcmVsb2FkLWNvbmZpZ3VyYXRpb24KICAgIGlmIFsgJD8gPSAgJE9DRl9TVUNDRVNTIF07IHRoZW4KICByZXR1cm4gJE9DRl9TVUNDRVNTCiAgICBmaQogICAgdG91Y2ggJHtPQ0ZfUkVTS0VZX3N0YXRlfQp9CgpqZW5raW5zX3N0b3AoKSB7CiAgICBqZW5raW5zX21vbml0b3IKICAgIGlmIFsgJD8gPSAgJE9DRl9TVUNDRVNTIF07IHRoZW4KICBybSAke09DRl9SRVNLRVlfc3RhdGV9CiAgICBmaQogICAgcmV0dXJuICRPQ0ZfU1VDQ0VTUwp9CgpqZW5raW5zX21vbml0b3IoKSB7CiAgaWYgWyAtZiAke09DRl9SRVNLRVlfc3RhdGV9IF07IHRoZW4KICAgICAgcmV0dXJuICRPQ0ZfU1VDQ0VTUwogIGZpCiAgaWYgZmFsc2UgOyB0aGVuCiAgICByZXR1cm4gJE9DRl9FUlJfR0VORVJJQwogIGZpCgogIGlmICEgb2NmX2lzX3Byb2JlICYmIFsgIiRfX09DRl9BQ1RJT04iID0gIm1vbml0b3IiIF07IHRoZW4KICAgIG9jZl9leGl0X3JlYXNvbiAiTm8gcHJvY2VzcyBzdGF0ZSBmaWxlIGZvdW5kIgogIGZpCiAgcmV0dXJuICRPQ0ZfTk9UX1JVTk5JTkcKfQoKamVua2luc192YWxpZGF0ZSgpIHsKICAgIHN0YXRlX2Rpcj1gZGlybmFtZSAiJE9DRl9SRVNLRVlfc3RhdGUiYAogICAgdG91Y2ggIiRzdGF0ZV9kaXIvJCQiCiAgICBpZiBbICQ/ICE9IDAgXTsgdGhlbgogIG9jZl9leGl0X3JlYXNvbiAiU3RhdGUgZmlsZSBcIiRPQ0ZfUkVTS0VZX3N0YXRlXCIgaXMgbm90IHdyaXRhYmxlIgogIHJldHVybiAkT0NGX0VSUl9BUkdTCiAgICBmaQogICAgcm0gIiRzdGF0ZV9kaXIvJCQiCgogICAgcmV0dXJuICRPQ0ZfU1VDQ0VTUwp9Cgo6ICR7T0NGX1JFU0tFWV9zdGF0ZT0ke0hBX1JTQ1RNUH0vSmVua2lucy0ke09DRl9SRVNPVVJDRV9JTlNUQU5DRX0uc3RhdGV9CgoKY2FzZSAkX19PQ0ZfQUNUSU9OIGluCm1ldGEtZGF0YSkgIG1ldGFfZGF0YQogICAgZXhpdCAkT0NGX1NVQ0NFU1MKICAgIDs7CnN0YXJ0KSAgICBqZW5raW5zX3N0YXJ0OzsKc3RvcCkgICBqZW5raW5zX3N0b3A7Owptb25pdG9yKSAgamVua2luc19tb25pdG9yOzsKbWlncmF0ZV90bykgb2NmX2xvZyBpbmZvICJNaWdyYXRpbmcgJHtPQ0ZfUkVTT1VSQ0VfSU5TVEFOQ0V9IHRvICR7T0NGX1JFU0tFWV9DUk1fbWV0YV9taWdyYXRlX3RhcmdldH0uIgogICAgICAgICAgamVua2luc19zdG9wCiAgICA7OwptaWdyYXRlX2Zyb20pIG9jZl9sb2cgaW5mbyAiTWlncmF0aW5nICR7T0NGX1JFU09VUkNFX0lOU1RBTkNFfSBmcm9tICR7T0NGX1JFU0tFWV9DUk1fbWV0YV9taWdyYXRlX3NvdXJjZX0uIgogICAgICAgICAgamVua2luc19zdGFydAogICAgOzsKcmVsb2FkKSAgIG9jZl9sb2cgaW5mbyAiUmVsb2FkaW5nICR7T0NGX1JFU09VUkNFX0lOU1RBTkNFfSAuLi4iCiAgICA7Owp2YWxpZGF0ZS1hbGwpIGplbmtpbnNfdmFsaWRhdGU7Owp1c2FnZXxoZWxwKSBqZW5raW5zX3VzYWdlCiAgICBleGl0ICRPQ0ZfU1VDQ0VTUwogICAgOzsKKikgICAgamVua2luc191c2FnZQogICAgZXhpdCAkT0NGX0VSUl9VTklNUExFTUVOVEVECiAgICA7Owplc2FjCnJjPSQ/Cm9jZl9sb2cgZGVidWcgIiR7T0NGX1JFU09VUkNFX0lOU1RBTkNFfSAkX19PQ0ZfQUNUSU9OIDogJHJjIgpleGl0ICRyYwo=
EOF
cat <<-EOF > /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    rrp_mode:active
    cluster_name: jenkins
    transport: udpu
    token: 17000
}

nodelist {
EOF
INDEX=1
for NODE in `aws ec2  describe-instances --filters "Name=tag:Name,Values=${cluster_name}" "Name=instance-state-name,Values=running" | jq -r .Reservations[].Instances[].PrivateIpAddress | sort`
  do echo "node {
        ring0_addr: ip-$${NODE//./-}
        nodeid: $(( INDEX++ ))
       }
" >> /etc/corosync/corosync.conf
done
echo "}

quorum {
    provider: corosync_votequorum
    expected_votes: 3
}" >> /etc/corosync/corosync.conf
crm configure property stonith-enabled=false
systemctl restart corosync pacemaker
crm configure primitive elastic-ip ocf:heartbeat:awseip params elastic_ip="${eip}" awscli="$(which aws)" allocation_id="${eip_allocation}" op start   timeout="60s" interval="0s"  on-fail="restart"     op monitor timeout="60s" interval="10s" on-fail="restart"     op stop    timeout="60s" interval="0s"  on-fail="block" meta migration-threshold="2" failure-timeout="60s" resource-stickiness="100"
crm configure primitive jenkins ocf:heartbeat:jenkins params login="${user}" password="${password}"
crm configure group jenkins-master elastic-ip jenkins
