#!/bin/bash

[[ "TRACE" ]] && set -x

if [ $ENABLE_KUBERNETES == 'false' -o $ENABLE_KUBERNETES == '' ]
then
  source /configg/hadoop/config
fi

: ${HADOOP_INSTALL:=/usr/local/hadoop}
: ${MASTER:=hdfs-master}
: ${DOMAIN_NAME:=cloud.com}
: ${DOMAIN_REALM:=$DOMAIN_NAME}
#: ${HDFS:=hdfs-master.cloud.com}
: ${KEY_PWD:=sumit@1234}
: ${ENABLE_HADOOP_SSL:=false}
: ${ENABLE_KERBEROS:=false}
: ${ENABLE_KUBERNETES:=false}
#: ${NAME_SERVER:=hdfs-master.cloud.com}
: ${HDFS_MASTER:=$MASTER.$DOMAIN_NAME}
: ${REALM:=$(echo $DOMAIN_NAME | tr 'a-z' 'A-Z')}

startSsh() {
 echo -e "Starting SSHD service"
 /usr/sbin/sshd
}

fix_hostname() {
  #sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
  if [ "$ENABLE_KUBERNETES" == 'true' ]
  then
   cp /etc/hosts ~/tmp
   sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/"  ~/tmp
   cp -f ~/tmp /etc/hosts
  fi
}

setEnvVariable() {

 if [ "$ENABLE_HADOOP_SSL" == 'true' ]
 then 
  fqdn=$(hostname -f)
  if [ $1 == 'master' ]
  then
   keyfile=${fqdn}.jks
  else
   keyfile=`sed -n 1p /usr/local/hadoop/etc/hadoop/slaves`.jks
  fi
 fi

 echo 'export JAVA_HOME=/usr/local/jdk' >> /etc/bash.bashrc
 echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/bash.bashrc
 echo 'export HADOOP_INSTALL=/usr/local/hadoop' >> /etc/bash.bashrc
 echo 'export PATH=$PATH:$HADOOP_INSTALL/bin' >> /etc/bash.bashrc
 echo 'export PATH=$PATH:$HADOOP_INSTALL/sbin' >> /etc/bash.bashrc
 echo 'export HADOOP_MAPRED_HOME=$HADOOP_INSTALL' >> /etc/bash.bashrc
 echo 'export HADOOP_COMMON_HOME=$HADOOP_INSTALL' >> /etc/bash.bashrc
 echo 'export HADOOP_HDFS_HOME=$HADOOP_INSTALL' >> /etc/bash.bashrc
 echo 'export YARN_HOME=$HADOOP_INSTALL' >> /etc/bash.bashrc
 echo 'export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_INSTALL/lib/native' >> /etc/bash.bashrc
 echo 'export HADOOP_OPTS="-Djava.library.path=$HADOOP_INSTALL/lib/native"' >> /etc/bash.bashrc
 echo 'export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop' >> /etc/bash.bashrc
 echo 'export LD_LIBRARY_PATH=/usr/local/lib:$HADOOP_INSTALL/lib/native:$LD_LIBRARY_PATH' >> /etc/bash.bashrc
 echo 'cd /usr/local/hadoop' >> /etc/bash.bashrc


 if [ "$ENABLE_KERBEROS" == 'false' ]
 then
   cp /tmp/config/hadoop/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/core-site.xml

   cp /tmp/config/hadoop/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/hdfs-site.xml

   cp /tmp/config/hadoop/mapred-site.xml /usr/local/hadoop/etc/hadoop/mapred-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/mapred-site.xml 

   cp /tmp/config/hadoop/yarn-site.xml /usr/local/hadoop/etc/hadoop/yarn-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/yarn-site.xml

   cp /tmp/config/hadoop/httpfs-site.xml /usr/local/hadoop/etc/hadoop/httpfs-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/httpfs-site.xml
 elif [ "$ENABLE_KERBEROS" == 'true' ]
 then
   
   if [ "$ENABLE_HADOOP_SSL" == 'false' ]
   then
     enableSecureLog
   fi

   cp /tmp/config/hadoop/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml
   cp /tmp/config/hadoop/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml
   cp /tmp/config/hadoop/mapred-site.xml /usr/local/hadoop/etc/hadoop/mapred-site.xml
   cp /tmp/config/hadoop/yarn-site.xml /usr/local/hadoop/etc/hadoop/yarn-site.xml
   cp /tmp/config/hadoop/httpfs-site.xml /usr/local/hadoop/etc/hadoop/httpfs-site.xml
   
   kerberizeNameNodeSerice
   kerberizeSecondaryNamenodeService
   kerberizeDataNodeService
   kerberizeYarnService
   kerberizeHttpfsService
   if [ "$ENABLE_HADOOP_SSL" == 'true' ]
   then
    mkdir -p /usr/local/hadoop/etc/hadoop/certs/
    cp -R /tmp/config/hadoop/certs/* /usr/local/hadoop/etc/hadoop/certs/ 
    cp /tmp/config/hadoop/ssl-server.xml $HADOOP_INSTALL/etc/hadoop/ssl-server.xml
    cp /tmp/config/hadoop/ssl-client.xml $HADOOP_INSTALL/etc/hadoop/ssl-client.xml
    enableSslService
    sedFile $HADOOP_INSTALL/etc/hadoop/ssl-server.xml
    sedFile $HADOOP_INSTALL/etc/hadoop/ssl-client.xml
   fi

   sedFile /usr/local/hadoop/etc/hadoop/core-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/hdfs-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/mapred-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/yarn-site.xml
   sedFile /usr/local/hadoop/etc/hadoop/httpfs-site.xml   
 fi

}

kerberizeHttpfsService(){
   /utility/hadoop/kerberizeHttpfs.sh /usr/local/hadoop/etc/hadoop/httpfs-site.xml
}

enableSslService(){
 /utility/hadoop/enableSSL.sh /usr/local/hadoop/etc/hadoop/core-site.xml
 /utility/hadoop/enableSSL.sh /usr/local/hadoop/etc/hadoop/hdfs-site.xml 
 /utility/hadoop/enableSSL.sh /usr/local/hadoop/etc/hadoop/mapred-site.xml
 #On secure datanodes, user to run the datanode as after dropping privileges
}

kerberizeNameNodeSerice(){

   /utility/hadoop/kerberizeNamenode.sh /usr/local/hadoop/etc/hadoop/core-site.xml
   /utility/hadoop/kerberizeNamenode.sh /usr/local/hadoop/etc/hadoop/hdfs-site.xml
}

kerberizeSecondaryNamenodeService(){
   /utility/hadoop/kerberizeSecondarynode.sh /usr/local/hadoop/etc/hadoop/hdfs-site.xml
}

kerberizeDataNodeService(){
   /utility/hadoop/kerberizeDatanode.sh /usr/local/hadoop/etc/hadoop/hdfs-site.xml
}

kerberizeYarnService(){
  /utility/hadoop/kerberizeYarn.sh /usr/local/hadoop/etc/hadoop/mapred-site.xml
  /utility/hadoop/kerberizeYarn.sh /usr/local/hadoop/etc/hadoop/yarn-site.xml
  echo 'yarn.nodemanager.linux-container-executor.group=hadoop
banned.users=bin
min.user.id=500
allowed.system.users=hduser' > $HADOOP_INSTALL/etc/hadoop/container-executor.cfg
  chmod 050 /usr/local/hadoop/bin/container-executor
  chmod u+s /usr/local/hadoop/bin/container-executor
  chmod g+s /usr/local/hadoop/bin/container-executor
  su - root -c "$HADOOP_INSTALL/bin/container-executor"
}


enableSecureLog(){

#Enable secure datanode
sed -i "s/\${HADOOP_SECURE_DN_USER}/hduser/g" /usr/local/hadoop/etc/hadoop/hadoop-env.sh
sed -i "/HADOOP_SECURE_DN_PID_DIR/ s/\${HADOOP_PID_DIR}/\/var\/run\/hadoop\/\$HADOOP_SECURE_DN_USER/g" /usr/local/hadoop/etc/hadoop/hadoop-env.sh
sed -i 's/HADOOP_SECURE_DN_LOG_DIR/^#/g' /usr/local/hadoop/etc/hadoop/hadoop-env.sh
echo 'export JSVC_HOME=/usr/bin' >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_SECURE_DN_LOG_DIR=/var/log/hadoop/$HADOOP_SECURE_DN_USER' >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh
}

sedFile(){
  filename=$1
  PRIV1=1006
  PRIV2=1019
  if [ "$ENABLE_HADOOP_SSL" == 'true' ]
  then
    PRIV1=50020
    PRIV2=50010
  fi
  #sed -i "s/\$NAME_SERVER/$NAME_SERVER/" $filename
  sed -i "s/\$HDFS_MASTER/$HDFS_MASTER/" $filename
  sed -i "s/\$PRIV1/$PRIV1/" $filename
  sed -i "s/\$PRIV2/$PRIV2/" $filename
  sed -i "s/\$REALM/$REALM/" $filename
  sed -i "s/_HOST/$(hostname -f)/g" $filename
  sed -i "s/HOSTNAME/$HDFS_MASTER/" $filename
  sed -i "s/DOMAIN_JKS/$keyfile/" $filename
  sed -i "s/JKS_KEY_PASSWORD/$KEY_PWD/" $filename
}


changeOwner() {
 chown -R hduser:hadoop /app/hadoop/tmp
 chown -R hduser:hadoop /usr/local/hadoop_store
 chown -R root:hadoop /usr/local/hadoop
}

initializePrincipal() {
 kadmin -p root/admin -w admin -q "addprinc -pw sumit root@$REALM"
 kadmin -p root/admin -w admin -q "addprinc -randkey hduser/$(hostname -f)@$REALM"
 kadmin -p root/admin -w admin -q "addprinc -randkey HTTP/$(hostname -f)@$REALM"
 
 kadmin -p root/admin -w admin -q "xst -k hduser.keytab hduser/$(hostname -f)@$REALM HTTP/$(hostname -f)@$REALM"

 mkdir -p /etc/security/keytabs
 mv hduser.keytab /etc/security/keytabs
 chmod 440 /etc/security/keytabs/hduser.keytab
 chown root:hadoop /etc/security/keytabs/hduser.keytab
}


startMaster() {
 su - root -c "$HADOOP_INSTALL/etc/hadoop/hadoop-env.sh"
 su - root -c "$HADOOP_INSTALL/sbin/hadoop-daemon.sh start namenode"
 su - root -c "$HADOOP_INSTALL/sbin/hadoop-daemon.sh start secondarynamenode"
 su - root -c "$HADOOP_INSTALL/sbin/hadoop-daemon.sh start datanode"
 su - root -c "$HADOOP_INSTALL/sbin/yarn-daemon.sh start resourcemanager"
 su - root -c "$HADOOP_INSTALL/sbin/yarn-daemon.sh start nodemanager"
 su - root -c "$HADOOP_INSTALL/sbin/mr-jobhistory-daemon.sh start historyserver --config /usr/local/hadoop/etc/hadoop"
 if [ "$ENABLE_KERBEROS" == 'true' ]
 then
  kinit -k -t /etc/security/keytabs/hduser.keytab hduser/$(hostname -f)
 fi
 su - root -c "$HADOOP_INSTALL/bin/hdfs dfs -mkdir -p /user/hduser"
 su - root -c "$HADOOP_INSTALL/bin/hdfs dfs -mkdir -p /user/hue"
 su - root -c "$HADOOP_INSTALL/bin/hdfs dfs -chmod g+w /user/hduser"
 su - root -c "$HADOOP_INSTALL/bin/hdfs dfs -chmod g+w /user/hue"
 su - root -c "$HADOOP_INSTALL/sbin/httpfs.sh start"
}

startSlave() {
 su - root -c "$HADOOP_INSTALL/etc/hadoop/hadoop-env.sh"
 su - root -c "$HADOOP_INSTALL/sbin/hadoop-daemon.sh --config /usr/local/hadoop/etc/hadoop --script hdfs start datanode"
 su - root -c "$HADOOP_INSTALL/sbin/yarn-daemons.sh --config /usr/local/hadoop/etc/hadoop  start nodemanager"
}

deamon() {
  while true; do sleep 1000; done
}

bashPrompt() {
 /bin/bash
}

sshPromt() {
 /usr/sbin/sshd -D
}

initialize() {
   if [[ $1 == 'master' ]] 
   then
   startMaster
   elif [[ $1 == 'slave' ]]
   then
    startSlave
   fi
}

setupHadoop(){
  
    if [ "$ENABLE_KERBEROS" == 'false' ]
    then
      fix_hostname  
    fi

    if [ "$ENABLE_KERBEROS" == 'true' ]
    then
     /utility/ldap/bootstrap.sh
    fi
    if [ "$ENABLE_KERBEROS" == 'true' ]
    then
     initializePrincipal
    fi

    changeOwner
    setEnvVariable $1
}

# $1: -s ==> Only setup hadoop
#     -a ==> Setup hadoop and start all the component
main() {
 if [ $1 == '-s' -a ! -f /hadoop_inistalled ]
 then
  setupHadoop $2
  touch /hadoop_inistalled
  exit 0
 elif [ $1 == '-a' -a ! -f /hadoop_inistalled ]
 then
  setupHadoop $2
  startSsh
  if [ $2 == 'master' ]
  then
    su - root -c "$HADOOP_INSTALL/bin/hdfs namenode -format"
  fi
  initialize $2
  touch /hadoop_inistalled
 elif [ ! -f /hadoop_inistalled ]
 then
  setupHadoop $2
  startSsh
  if [ $2 == 'master' ]
  then
    su - root -c "$HADOOP_INSTALL/bin/hdfs namenode -format"
  fi
  initialize $2
  touch /hadoop_inistalled
 elif [ -f /hadoop_inistalled ]
 then
  startSsh
  initialize $2  
 fi


 #if [ ! -f /hadoop_initialized ]; then
 #   setupHadoop $2
 #   startSsh
 #   su - root -c "$HADOOP_INSTALL/bin/hdfs namenode -format"
 #   initialize $2
 #   touch /hadoop_initialized
 # else
 #   startSsh
 #   initialize $2
 # fi
  #tail -f $HADOOP_INSTALL/logs/hadoop-root-namenode-$HDFS.log mapred-root-historyserver-$HDFS.log yarn-root-resourcemanager-$HDFS.log httpfs.log hadoop-root-datanode-$HDFS.log yarn-root-nodemanager-$HDFS.log hadoop-root-secondarynamenode-$HDFS.log

  if [[ $1 == "-d" ]]; then
   deamon
  fi

}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"