#!/bin/bash
set -e

# =========================
# Configuration
# =========================
HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
HDFS_NAMENODE_DIR=/tmp/hadoop/namenode
HDFS_DATANODE_DIR=/tmp/hadoop/datanode

# =========================
# Detect and set JAVA_HOME
# =========================
if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "JAVA_HOME not set or invalid, attempting to detect..."
    if command -v javac >/dev/null 2>&1; then
        DETECTED_JAVA_HOME=$(readlink -f $(which javac) | sed "s:/bin/javac::")
        export JAVA_HOME="$DETECTED_JAVA_HOME"
        echo "Detected JAVA_HOME: $JAVA_HOME"
    else
        echo "ERROR: Java not found"
        exit 1
    fi
fi

# Update hadoop-env.sh with correct JAVA_HOME
echo "export JAVA_HOME=$JAVA_HOME" > $HADOOP_HOME/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"' >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_NICENESS=0' >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# =========================
# Logging function
# =========================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# =========================
# Start SSH service
# =========================
log "Starting SSH service..."
sudo service ssh start || {
    log "Failed to start SSH service, trying alternative..."
    sudo /usr/sbin/sshd -D &
}

# Wait for SSH to be ready
sleep 3

# =========================
# Test SSH connectivity
# =========================
log "Testing SSH connectivity..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no localhost echo "SSH test" 2>/dev/null; then
    log "SSH connection failed, reconfiguring..."
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        sudo ssh-keygen -A
    fi
    sudo service ssh restart
    sleep 5
fi

# =========================
# Setup directories and permissions
# =========================
log "Setting up directories and permissions..."
mkdir -p /tmp/hadoop/namenode /tmp/hadoop/datanode
chmod 755 /tmp/hadoop /tmp/hadoop/namenode /tmp/hadoop/datanode

# Fix Hadoop configuration file permissions
sudo chown -R hadoop:hadoop $HADOOP_HOME/etc/hadoop/
chmod 644 $HADOOP_HOME/etc/hadoop/*.xml
chmod 755 $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# =========================
# Format HDFS if needed
# =========================
if [ ! -d "$HDFS_NAMENODE_DIR/current" ]; then
    log "Formatting NameNode..."
    $HADOOP_HOME/bin/hdfs namenode -format -force -nonInteractive
else
    log "HDFS already formatted."
fi

# =========================
# Start Hadoop Services
# =========================
log "Starting HDFS..."
$HADOOP_HOME/sbin/start-dfs.sh

# Wait for HDFS to be ready
log "Waiting for HDFS to start..."
HDFS_READY=false
for i in {1..60}; do
    if pgrep -f NameNode >/dev/null && pgrep -f DataNode >/dev/null; then
        if $HADOOP_HOME/bin/hdfs dfsadmin -report >/dev/null 2>&1; then
            log "HDFS is ready"
            HDFS_READY=true
            break
        fi
    fi
    log "Waiting for HDFS... ($i/60)"
    sleep 3
done

if [ "$HDFS_READY" = false ]; then
    log "Warning: HDFS did not start properly within timeout"
    log "NameNode status: $(pgrep -f NameNode >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
    log "DataNode status: $(pgrep -f DataNode >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
fi

log "Starting YARN..."
$HADOOP_HOME/sbin/start-yarn.sh

# Wait for YARN to be ready
log "Waiting for YARN to start..."
YARN_READY=false
for i in {1..60}; do
    if pgrep -f ResourceManager >/dev/null && pgrep -f NodeManager >/dev/null; then
        if curl -s -f http://localhost:8088/ws/v1/cluster/info >/dev/null 2>&1; then
            log "YARN is ready"
            YARN_READY=true
            break
        fi
    fi
    log "Waiting for YARN... ($i/60)"
    sleep 3
done

if [ "$YARN_READY" = false ]; then
    log "Warning: YARN did not start properly within timeout"
    log "ResourceManager status: $(pgrep -f ResourceManager >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
    log "NodeManager status: $(pgrep -f NodeManager >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
fi

# =========================
# Setup HDFS directories
# =========================
if [ "$HDFS_READY" = true ]; then
    log "Creating HDFS directories..."
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hadoop/input 2>/dev/null || true
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hadoop/output 2>/dev/null || true
    $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/hadoop/mapreduce-jobs 2>/dev/null || true

    log "Setting HDFS permissions..."
    $HADOOP_HOME/bin/hdfs dfs -chmod 755 /user/hadoop 2>/dev/null || true
    $HADOOP_HOME/bin/hdfs dfs -chmod 777 /tmp 2>/dev/null || true
fi

# =========================
# Display cluster status
# =========================
log "Displaying cluster status..."
echo "==================== HADOOP CLUSTER STATUS ===================="
echo "NameNode: $(pgrep -f NameNode >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "DataNode: $(pgrep -f DataNode >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "ResourceManager: $(pgrep -f ResourceManager >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "NodeManager: $(pgrep -f NodeManager >/dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "=============================================================="
echo "Web Interfaces:"
echo "- NameNode UI:        http://localhost:9870"
echo "- ResourceManager UI: http://localhost:8088"
echo "- DataNode UI:        http://localhost:9864"
echo "=============================================================="

# Display JPS output
log "Java processes (jps output):"
jps -l

# Test basic HDFS functionality
if [ "$HDFS_READY" = true ]; then
    log "Testing HDFS functionality..."
    echo "test data" | $HADOOP_HOME/bin/hdfs dfs -put - /tmp/test-file 2>/dev/null && \
    $HADOOP_HOME/bin/hdfs dfs -rm /tmp/test-file 2>/dev/null && \
    log "HDFS functionality test: PASSED" || \
    log "HDFS functionality test: FAILED"
fi

# =========================
# Keep container alive and monitor services
# =========================
log "Hadoop cluster startup completed!"
log "Container is ready for use. Access with: docker exec -it <container-name> bash"

# Function to check and restart failed services
check_and_restart_services() {
    local restart_needed=false

    if ! pgrep -f NameNode >/dev/null; then
        log "NameNode died! Attempting restart..."
        $HADOOP_HOME/sbin/start-dfs.sh
        restart_needed=true
    fi

    if ! pgrep -f ResourceManager >/dev/null; then
        log "ResourceManager died! Attempting restart..."
        $HADOOP_HOME/sbin/start-yarn.sh
        restart_needed=true
    fi

    if [ "$restart_needed" = true ]; then
        sleep 10
        log "Service restart completed. Current status:"
        jps -l
    fi
}

# Monitor services every 30 seconds
while true; do
    sleep 30
    check_and_restart_services
done