# =========================
# Hadoop Docker Setup (Standalone / MapReduce)
# =========================
FROM ubuntu:20.04

# =========================
# Environment Variables
# =========================
ENV DEBIAN_FRONTEND=noninteractive
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HADOOP_LOG_DIR=/opt/hadoop/logs
ENV HADOOP_MAPRED_HOME=$HADOOP_HOME
ENV HADOOP_COMMON_HOME=$HADOOP_HOME
ENV HADOOP_HDFS_HOME=$HADOOP_HOME
ENV HADOOP_YARN_HOME=$HADOOP_HOME
ENV HOME=/home/hadoop
ENV HADOOP_NICENESS=0

# =========================
# System Setup & Dependencies
# =========================
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jdk \
    curl \
    wget \
    openssh-client \
    openssh-server \
    rsync \
    vim \
    net-tools \
    sudo \
    procps \
    haveged \
    netcat \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME dynamically
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
RUN if [ ! -d "$JAVA_HOME" ]; then \
        JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::") && \
        export JAVA_HOME; \
    fi
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$JAVA_HOME/bin

# =========================
# Create Hadoop User
# =========================
RUN groupadd -r hadoop && \
    useradd -r -g hadoop -d /home/hadoop -s /bin/bash -c "Hadoop User" hadoop && \
    mkdir -p /home/hadoop && \
    chown -R hadoop:hadoop /home/hadoop && \
    echo 'hadoop ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# =========================
# Copy Hadoop tar and extract
# =========================
COPY hadoop-3.3.6.tar.gz /tmp/hadoop.tar.gz
RUN mkdir -p $HADOOP_HOME && \
    tar -xzf /tmp/hadoop.tar.gz -C $HADOOP_HOME --strip-components=1 && \
    rm -f /tmp/hadoop.tar.gz && \
    mkdir -p $HADOOP_LOG_DIR && chmod 755 $HADOOP_LOG_DIR && \
    chown -R hadoop:hadoop $HADOOP_HOME

# =========================
# SSH Setup
# =========================
RUN mkdir -p /home/hadoop/.ssh && \
    chmod 700 /home/hadoop/.ssh && \
    ssh-keygen -t rsa -b 2048 -f /home/hadoop/.ssh/id_rsa -N "" -q && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chmod 600 /home/hadoop/.ssh/authorized_keys /home/hadoop/.ssh/id_rsa && \
    touch /home/hadoop/.ssh/known_hosts && \
    chown -R hadoop:hadoop /home/hadoop/.ssh

# SSH config file
RUN echo "Host localhost" > /home/hadoop/.ssh/config && \
    echo "  StrictHostKeyChecking no" >> /home/hadoop/.ssh/config && \
    echo "  UserKnownHostsFile=/dev/null" >> /home/hadoop/.ssh/config && \
    echo "  LogLevel=ERROR" >> /home/hadoop/.ssh/config && \
    chmod 600 /home/hadoop/.ssh/config && \
    chown hadoop:hadoop /home/hadoop/.ssh/config

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# =========================
# Hadoop XML Configurations
# =========================
RUN mkdir -p $HADOOP_CONF_DIR

# core-site.xml
RUN echo '<?xml version="1.0"?>' > $HADOOP_CONF_DIR/core-site.xml && \
    echo '<configuration>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '        <name>fs.defaultFS</name>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '        <value>hdfs://localhost:9000</value>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '        <name>hadoop.tmp.dir</name>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '        <value>/tmp/hadoop</value>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/core-site.xml && \
    echo '</configuration>' >> $HADOOP_CONF_DIR/core-site.xml

# hdfs-site.xml
RUN echo '<?xml version="1.0"?>' > $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '<configuration>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <name>dfs.replication</name>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <value>1</value>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <name>dfs.namenode.name.dir</name>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <value>/tmp/hadoop/namenode</value>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <name>dfs.datanode.data.dir</name>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <value>/tmp/hadoop/datanode</value>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <name>dfs.permissions.enabled</name>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '        <value>false</value>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/hdfs-site.xml && \
    echo '</configuration>' >> $HADOOP_CONF_DIR/hdfs-site.xml

# mapred-site.xml - CRITICAL FIX for MapReduce
RUN echo '<?xml version="1.0"?>' > $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '<configuration>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.framework.name</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>yarn</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.application.classpath</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>yarn.app.mapreduce.am.env</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>HADOOP_MAPRED_HOME=/opt/hadoop</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.map.env</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>HADOOP_MAPRED_HOME=/opt/hadoop</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.reduce.env</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>HADOOP_MAPRED_HOME=/opt/hadoop</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.map.memory.mb</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>512</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.reduce.memory.mb</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>512</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>yarn.app.mapreduce.am.resource.mb</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>512</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <name>mapreduce.task.timeout</name>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '        <value>600000</value>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/mapred-site.xml && \
    echo '</configuration>' >> $HADOOP_CONF_DIR/mapred-site.xml

# yarn-site.xml - Enhanced with proper memory settings
RUN echo '<?xml version="1.0"?>' > $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '<configuration>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.nodemanager.aux-services</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>mapreduce_shuffle</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.resourcemanager.hostname</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>localhost</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.nodemanager.env-whitelist</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.scheduler.maximum-allocation-mb</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>1024</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.nodemanager.resource.memory-mb</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>1024</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.nodemanager.resource.cpu-vcores</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>1</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    <property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <name>yarn.scheduler.minimum-allocation-mb</name>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '        <value>256</value>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '    </property>' >> $HADOOP_CONF_DIR/yarn-site.xml && \
    echo '</configuration>' >> $HADOOP_CONF_DIR/yarn-site.xml

# hadoop-env.sh with comprehensive environment setup
RUN echo '#!/bin/bash' > $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_HOME=/opt/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_MAPRED_HOME=/opt/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_COMMON_HOME=/opt/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_HDFS_HOME=/opt/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_YARN_HOME=/opt/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    echo 'export HADOOP_NICENESS=0' >> $HADOOP_CONF_DIR/hadoop-env.sh && \
    chmod 755 $HADOOP_CONF_DIR/hadoop-env.sh

# =========================
# Directories & Permissions
# =========================
RUN mkdir -p /tmp/hadoop/namenode /tmp/hadoop/datanode \
    /home/hadoop/input /home/hadoop/output /home/hadoop/mapreduce-jobs && \
    chown -R hadoop:hadoop /tmp/hadoop $HADOOP_HOME /home/hadoop

# =========================
# Copy startup & healthcheck scripts
# =========================
COPY start-hadoop.sh /home/hadoop/start-hadoop.sh
RUN chown hadoop:hadoop /home/hadoop/start-hadoop.sh && chmod +x /home/hadoop/start-hadoop.sh

# Create enhanced health check
RUN echo '#!/bin/bash' > /home/hadoop/health-check.sh && \
    echo 'failed_services=0' >> /home/hadoop/health-check.sh && \
    echo 'check_service() {' >> /home/hadoop/health-check.sh && \
    echo '  local cmd=$1' >> /home/hadoop/health-check.sh && \
    echo '  if ! eval $cmd >/dev/null 2>&1; then' >> /home/hadoop/health-check.sh && \
    echo '    ((failed_services++))' >> /home/hadoop/health-check.sh && \
    echo '  fi' >> /home/hadoop/health-check.sh && \
    echo '}' >> /home/hadoop/health-check.sh && \
    echo 'check_service "pgrep -f NameNode"' >> /home/hadoop/health-check.sh && \
    echo 'check_service "pgrep -f DataNode"' >> /home/hadoop/health-check.sh && \
    echo 'check_service "pgrep -f ResourceManager"' >> /home/hadoop/health-check.sh && \
    echo 'check_service "pgrep -f NodeManager"' >> /home/hadoop/health-check.sh && \
    echo '[ $failed_services -eq 0 ] && exit 0 || exit 1' >> /home/hadoop/health-check.sh && \
    chown hadoop:hadoop /home/hadoop/health-check.sh && chmod +x /home/hadoop/health-check.sh

# =========================
# Ports
# =========================
EXPOSE 9000 9870 8088 8042 19888 22

# =========================
# Metadata
# =========================
LABEL maintainer="dharunjisnu109@gmail.com"
LABEL version="2.2"
LABEL description="Hadoop 3.3.6 standalone cluster with Java 11 and MapReduce fixes"
LABEL hadoop.version="3.3.6"
LABEL java.version="11"

# =========================
# Switch to Hadoop user
# =========================
USER hadoop
WORKDIR /home/hadoop

# =========================
# Healthcheck & EntryPoint
# =========================
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 CMD ./health-check.sh
ENTRYPOINT ["./start-hadoop.sh"]