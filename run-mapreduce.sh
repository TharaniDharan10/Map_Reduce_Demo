#!/bin/bash
# Complete MapReduce Workflow Script
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONTAINER_NAME="hadoop-cluster"
IMAGE_NAME="hadoop:latest"

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# =========================
# Step 1: Check prerequisites
# =========================
log "Checking prerequisites..."

[ ! -f "input.txt" ] && error "input.txt not found in project root!"
[ ! -f "pom.xml" ] && error "pom.xml not found - are you in the project root?"

if ! command -v mvn >/dev/null 2>&1; then
    error "Maven not found. Please install Maven."
fi

if ! docker info >/dev/null 2>&1; then
    error "Docker not running. Please start Docker."
fi

# =========================
# Step 2: Build JAR
# =========================
log "Building JAR with Maven..."
if ! mvn clean package -q; then
    error "Maven build failed!"
fi

[ ! -f "target/MR_DEMO_JAR.jar" ] && error "JAR file not created!"
log "JAR built successfully: target/MR_DEMO_JAR.jar"

# =========================
# Step 3: Ensure container is running
# =========================
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "Container already running"
else
    log "Starting Hadoop container..."

    # Check if image exists
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        error "Docker image not found. Build it first with: docker build -t hadoop:latest ."
    fi

    # Clean up any stopped container with same name
    docker rm $CONTAINER_NAME 2>/dev/null || true

    # Start container
    docker run -d --name $CONTAINER_NAME \
        -p 9870:9870 -p 8088:8088 -p 9000:9000 -p 9864:9864 \
        $IMAGE_NAME

    log "Waiting for Hadoop services (45 seconds)..."
    sleep 45

    # Verify services
    log "Verifying services..."
    docker exec $CONTAINER_NAME bash -c "
        pgrep -f NameNode >/dev/null && echo 'NameNode: OK' || echo 'NameNode: FAILED'
        pgrep -f DataNode >/dev/null && echo 'DataNode: OK' || echo 'DataNode: FAILED'
        pgrep -f ResourceManager >/dev/null && echo 'ResourceManager: OK' || echo 'ResourceManager: FAILED'
        pgrep -f NodeManager >/dev/null && echo 'NodeManager: OK' || echo 'NodeManager: FAILED'
    "
fi

# =========================
# Step 4: Copy files to container
# =========================
log "Copying JAR and input files..."
docker cp target/MR_DEMO_JAR.jar $CONTAINER_NAME:/home/hadoop/
docker cp input.txt $CONTAINER_NAME:/home/hadoop/

# =========================
# Step 5: Run MapReduce job using Method 2 (Working approach)
# =========================
log "Running MapReduce job..."
info "Input data:"
cat input.txt
echo ""

docker exec $CONTAINER_NAME bash -c "
    set -e

    # Setup HDFS
    echo '==> Setting up HDFS directories...'
    hdfs dfs -mkdir -p /user/hadoop/input 2>/dev/null || true
    hdfs dfs -mkdir -p /user/hadoop/output 2>/dev/null || true

    # Upload input
    echo '==> Uploading input.txt to HDFS...'
    hdfs dfs -put -f input.txt /user/hadoop/input/

    # Clean output
    echo '==> Cleaning previous output...'
    hdfs dfs -rm -r -f /user/hadoop/output/sales-analysis 2>/dev/null || true

    # Run MapReduce using METHOD 2 (the one that works!)
    echo '==> Running MapReduce job (Method 2: HADOOP_CLASSPATH)...'
    export HADOOP_CLASSPATH=MR_DEMO_JAR.jar

    if hadoop MR_Demo.demo.DemoApplication /user/hadoop/input/input.txt /user/hadoop/output/sales-analysis; then
        echo ''
        echo '======================================'
        echo 'SUCCESS! MapReduce Job Completed!'
        echo '======================================'

        # Get results
        hdfs dfs -get /user/hadoop/output/sales-analysis/part-r-00000 /home/hadoop/output/results.txt

        echo 'Results (Company -> Total Sales):'
        echo '--------------------------------------'
        cat /home/hadoop/output/results.txt
        echo '======================================'

        exit 0
    else
        echo 'MapReduce job FAILED!'
        exit 1
    fi
"

# =========================
# Step 6: Copy results to host
# =========================
if [ $? -eq 0 ]; then
    log "Copying results to local ./output/ directory..."
    mkdir -p output
    docker cp $CONTAINER_NAME:/home/hadoop/output/results.txt output/

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}FINAL RESULTS${NC}"
    echo -e "${BLUE}========================================${NC}"
    cat output/results.txt
    echo -e "${BLUE}========================================${NC}"
    echo ""

    log "Results saved to: ./output/results.txt"
    info "Web UI: http://localhost:8088"
    info "Container: docker exec -it $CONTAINER_NAME bash"

    echo ""
    log "MapReduce execution completed successfully!"
else
    error "MapReduce job failed. Check container logs: docker logs $CONTAINER_NAME"
fi