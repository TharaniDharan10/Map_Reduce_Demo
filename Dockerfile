# =========================
# Hadoop MapReduce Docker Setup
# =========================
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HADOOP_MAPRED_HOME=$HADOOP_HOME
ENV HADOOP_COMMON_HOME=$HADOOP_HOME
ENV HADOOP_HDFS_HOME=$HADOOP_HOME
ENV HADOOP_YARN_HOME=$HADOOP_HOME
ENV HOME=/home/hadoop

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jdk curl wget openssh-client openssh-server \
    rsync vim sudo procps netcat coreutils && \
    rm -rf /var/lib/apt/lists/*

# Set Java Home
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$JAVA_HOME/bin

# Create Hadoop user
RUN groupadd -r hadoop && \
    useradd -r -g hadoop -d /home/hadoop -s /bin/bash hadoop && \
    mkdir -p /home/hadoop && chown -R hadoop:hadoop /home/hadoop && \
    echo 'hadoop ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Hadoop
COPY hadoop-3.3.6.tar.gz /tmp/
RUN tar -xzf /tmp/hadoop-3.3.6.tar.gz -C /opt/ && \
    mv /opt/hadoop-3.3.6 /opt/hadoop && \
    rm /tmp/hadoop-3.3.6.tar.gz && \
    chown -R hadoop:hadoop $HADOOP_HOME

# SSH Setup
RUN mkdir -p /home/hadoop/.ssh && chmod 700 /home/hadoop/.ssh && \
    ssh-keygen -t rsa -b 2048 -f /home/hadoop/.ssh/id_rsa -N "" -q && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chmod 600 /home/hadoop/.ssh/authorized_keys /home/hadoop/.ssh/id_rsa && \
    echo "Host localhost" > /home/hadoop/.ssh/config && \
    echo "  StrictHostKeyChecking no" >> /home/hadoop/.ssh/config && \
    chmod 600 /home/hadoop/.ssh/config && \
    chown -R hadoop:hadoop /home/hadoop/.ssh && \
    mkdir -p /var/run/sshd

# Hadoop Configuration Files
RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<configuration>' \
    '  <property><name>fs.defaultFS</name><value>hdfs://localhost:9000</value></property>' \
    '  <property><name>hadoop.tmp.dir</name><value>/tmp/hadoop</value></property>' \
    '</configuration>' \
    > $HADOOP_CONF_DIR/core-site.xml

RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<configuration>' \
    '  <property><name>dfs.replication</name><value>1</value></property>' \
    '  <property><name>dfs.namenode.name.dir</name><value>/tmp/hadoop/namenode</value></property>' \
    '  <property><name>dfs.datanode.data.dir</name><value>/tmp/hadoop/datanode</value></property>' \
    '  <property><name>dfs.permissions.enabled</name><value>false</value></property>' \
    '</configuration>' \
    > $HADOOP_CONF_DIR/hdfs-site.xml

RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<configuration>' \
    '  <property><name>mapreduce.framework.name</name><value>yarn</value></property>' \
    '  <property><name>yarn.app.mapreduce.am.env</name><value>HADOOP_MAPRED_HOME=/opt/hadoop</value></property>' \
    '  <property><name>mapreduce.map.env</name><value>HADOOP_MAPRED_HOME=/opt/hadoop</value></property>' \
    '  <property><name>mapreduce.reduce.env</name><value>HADOOP_MAPRED_HOME=/opt/hadoop</value></property>' \
    '  <property><name>mapreduce.map.memory.mb</name><value>512</value></property>' \
    '  <property><name>mapreduce.reduce.memory.mb</name><value>512</value></property>' \
    '  <property><name>yarn.app.mapreduce.am.resource.mb</name><value>512</value></property>' \
    '</configuration>' \
    > $HADOOP_CONF_DIR/mapred-site.xml

RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<configuration>' \
    '  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>' \
    '  <property><name>yarn.resourcemanager.hostname</name><value>localhost</value></property>' \
    '  <property><name>yarn.nodemanager.env-whitelist</name><value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value></property>' \
    '  <property><name>yarn.scheduler.maximum-allocation-mb</name><value>1024</value></property>' \
    '  <property><name>yarn.nodemanager.resource.memory-mb</name><value>1024</value></property>' \
    '  <property><name>yarn.scheduler.minimum-allocation-mb</name><value>256</value></property>' \
    '</configuration>' \
    > $HADOOP_CONF_DIR/yarn-site.xml

RUN printf '%s\n' \
    'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' \
    'export HADOOP_HOME=/opt/hadoop' \
    'export HADOOP_MAPRED_HOME=/opt/hadoop' \
    'export HADOOP_COMMON_HOME=/opt/hadoop' \
    'export HADOOP_HDFS_HOME=/opt/hadoop' \
    'export HADOOP_YARN_HOME=/opt/hadoop' \
    > $HADOOP_CONF_DIR/hadoop-env.sh && chmod 755 $HADOOP_CONF_DIR/hadoop-env.sh

# Create directories
RUN mkdir -p /tmp/hadoop/namenode /tmp/hadoop/datanode /home/hadoop/output && \
    chown -R hadoop:hadoop /tmp/hadoop $HADOOP_HOME /home/hadoop

# Startup script
COPY start-hadoop.sh /home/hadoop/
RUN chmod +x /home/hadoop/start-hadoop.sh && \
    chown hadoop:hadoop /home/hadoop/start-hadoop.sh

USER hadoop
WORKDIR /home/hadoop
EXPOSE 9000 9870 8088 9864

ENTRYPOINT ["./start-hadoop.sh"]