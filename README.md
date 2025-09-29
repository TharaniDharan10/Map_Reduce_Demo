# Hadoop MapReduce Sales Analysis Demo

A containerized Hadoop MapReduce application for analyzing sales data by company. This project demonstrates a complete end-to-end MapReduce workflow using Docker, making it easy to run Hadoop locally without complex setup.

## Overview

This MapReduce application processes sales transaction data and calculates total sales per company. It uses:
- **Hadoop 3.3.6** for distributed processing
- **Java 11** for MapReduce implementation
- **Docker** for containerization
- **Maven** for build management

### How It Works

The application reads sales data in CSV format (ID, Company, Product, Price) and aggregates total sales by company using MapReduce:
- **Mapper**: Extracts company name and price from each transaction
- **Reducer**: Sums up all prices for each company

---

## Prerequisites

Before you begin, ensure you have the following installed on your system:

### Required Software

1. **Docker Desktop** (or Docker Engine)
   - macOS: [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Windows: [Download Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Linux: Install via package manager
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install docker.io
   
   # Verify installation
   docker --version
   ```

2. **Java Development Kit (JDK) 11**
   ```bash
   # macOS (using Homebrew)
   brew install openjdk@11
   
   # Ubuntu/Debian
   sudo apt-get install openjdk-11-jdk
   
   # Verify installation
   java -version
   ```

3. **Apache Maven**
   ```bash
   # macOS (using Homebrew)
   brew install maven
   
   # Ubuntu/Debian
   sudo apt-get install maven
   
   # Verify installation
   mvn -version
   ```

### System Requirements

- **RAM**: Minimum 4GB available (8GB recommended)
- **Disk Space**: ~3GB for Docker image and Hadoop
- **OS**: macOS, Linux, or Windows 10/11 with WSL2

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Map_Reduce_Demo.git
cd Map_Reduce_Demo
```

### 2. Download Hadoop Distribution

Download Hadoop 3.3.6 tarball and place it in the project root:

```bash
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
```

**Note**: This file is ~600MB and required for building the Docker image.

### 3. Make Scripts Executable

```bash
chmod +x build.sh start-hadoop.sh run-mapreduce.sh
```

### 4. Build Docker Image

Build the Hadoop Docker image (this takes 5-10 minutes):

```bash
./build.sh
```

**Expected output:**
```
[HH:MM:SS] Checking prerequisites...
[HH:MM:SS] Building Docker image: hadoop:latest
[HH:MM:SS] This will take several minutes...
[HH:MM:SS] Docker image built successfully!
```

### 5. Prepare Your Input Data

Create or edit `input.txt` in the project root with your sales data:

```csv
1,amazon,mobile,2000
2,flipkart,laptop,50000
3,amazon,tablet,15000
4,flipkart,mobile,18000
5,amazon,laptop,45000
6,flipkart,tablet,12000
```

**Format**: `ID,Company,Product,Price`

### 6. Run MapReduce Job

Execute the complete workflow:

```bash
./run-mapreduce.sh
```

This script will:
1. Build your JAR file using Maven
2. Start the Hadoop container (if not already running)
3. Copy files to the container
4. Upload data to HDFS
5. Execute the MapReduce job
6. Display results in the console
7. Save results to `output/results.txt`

**Expected output:**
```
[HH:MM:SS] Building JAR with Maven...
[HH:MM:SS] JAR built successfully
[HH:MM:SS] Running MapReduce job...
======================================
SUCCESS! MapReduce Job Completed!
======================================
Results (Company -> Total Sales):
--------------------------------------
amazon   62000
flipkart 80000
======================================
```

---

## Project Structure

```
Map_Reduce_Demo/
├── Dockerfile                      # Hadoop container definition
├── start-hadoop.sh                 # Container startup script
├── build.sh                        # Docker image build script
├── run-mapreduce.sh                # Main execution script
├── hadoop-3.3.6.tar.gz            # Hadoop distribution (download separately)
├── input.txt                       # Your sales data (edit as needed)
├── pom.xml                         # Maven configuration
├── src/
│   └── main/
│       └── java/
│           └── MR_Demo/
│               └── demo/
│                   ├── DemoApplication.java    # Main MapReduce driver
│                   ├── Mapper/
│                   │   └── MapClass.java       # Mapper implementation
│                   └── Reducer/
│                       └── ReducerClass.java   # Reducer implementation
├── target/                         # Maven build output (auto-generated)
│   └── MR_DEMO_JAR.jar            # Compiled JAR file
└── output/                         # Results directory (auto-generated)
    └── results.txt                 # MapReduce output
```

---

## Detailed Usage

### Running MapReduce with Different Data

1. **Edit `input.txt`** with your sales transactions
2. **Run the script**:
   ```bash
   ./run-mapreduce.sh
   ```
3. **View results** in console and `output/results.txt`

### Accessing the Hadoop Container

To interact with the Hadoop cluster directly:

```bash
docker exec -it hadoop-cluster bash
```

Inside the container, you can run Hadoop commands:

```bash
# List HDFS files
hdfs dfs -ls /user/hadoop/input

# View input data
hdfs dfs -cat /user/hadoop/input/input.txt

# View output
hdfs dfs -cat /user/hadoop/output/sales-analysis/part-r-00000

# Check HDFS status
hdfs dfsadmin -report

# View running applications
yarn application -list
```

### Accessing Web Interfaces

Once the container is running, access Hadoop web UIs:

- **NameNode UI**: [http://localhost:9870](http://localhost:9870)
  - View HDFS status, browse files, check datanodes
  
- **ResourceManager UI**: [http://localhost:8088](http://localhost:8088)
  - Monitor MapReduce jobs, view application logs, check cluster resources

- **DataNode UI**: [http://localhost:9864](http://localhost:9864)
  - View datanode status and storage information

### Stopping the Container

```bash
docker stop hadoop-cluster
```

### Starting Existing Container

If you stopped the container and want to restart it:

```bash
docker start hadoop-cluster
```

Then wait ~30 seconds for services to initialize before running jobs.

### Removing the Container

To completely remove the container:

```bash
docker stop hadoop-cluster
docker rm hadoop-cluster
```

### Rebuilding Everything

If you encounter issues, clean rebuild:

```bash
# Remove container and image
docker stop hadoop-cluster 2>/dev/null || true
docker rm hadoop-cluster 2>/dev/null || true
docker rmi hadoop:latest 2>/dev/null || true

# Rebuild from scratch
./build.sh
./run-mapreduce.sh
```

---

## Customizing the MapReduce Job

### Modifying the Mapper

Edit `src/main/java/MR_Demo/demo/Mapper/MapClass.java`:

```java
@Override
protected void map(LongWritable key, Text value, Context context)
        throws IOException, InterruptedException {
    String line = value.toString();
    String[] elements = line.split(",");
    
    // Change parsing logic here
    Text keyWord = new Text(elements[1]);      // Company name
    int price = Integer.parseInt(elements[3]); // Price
    
    context.write(keyWord, new IntWritable(price));
}
```

### Modifying the Reducer

Edit `src/main/java/MR_Demo/demo/Reducer/ReducerClass.java`:

```java
@Override
protected void reduce(Text key, Iterable<IntWritable> values, Context context)
        throws IOException, InterruptedException {
    int sum = 0;
    for (IntWritable val : values) {
        sum += val.get();
    }
    // Modify aggregation logic here
    context.write(key, new IntWritable(sum));
}
```

After modifying code, run `./run-mapreduce.sh` again - it will automatically rebuild the JAR.

---

## Troubleshooting

### Docker Build Fails

**Problem**: Error during `./build.sh`

**Solutions**:
- Ensure `hadoop-3.3.6.tar.gz` is in project root
- Check Docker is running: `docker info`
- Verify `start-hadoop.sh` exists and is readable
- Check disk space: `df -h`

### Container Won't Start

**Problem**: Container starts but immediately stops

**Solutions**:
```bash
# Check logs
docker logs hadoop-cluster

# Verify ports aren't in use
lsof -i :9870
lsof -i :8088

# Try using different ports
docker run -d --name hadoop-cluster \
    -p 19870:9870 -p 18088:8088 -p 19864:9864 \
    hadoop:latest
```

### MapReduce Job Fails

**Problem**: Job fails with "ClassNotFoundException" or "Could not find main class"

**Solutions**:
- Ensure your code compiles: `mvn clean package`
- Check JAR structure: `jar -tf target/MR_DEMO_JAR.jar | grep DemoApplication`
- Verify no Spring Boot dependencies in `pom.xml`
- Check container logs: `docker exec hadoop-cluster cat /opt/hadoop/logs/yarn-hadoop-resourcemanager-*.log`

### Services Not Starting

**Problem**: JPS shows no processes or missing services

**Solutions**:
```bash
# Inside container
docker exec -it hadoop-cluster bash

# Check Java
java -version

# Manually start services
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh

# Check logs
tail -f $HADOOP_HOME/logs/hadoop-hadoop-namenode-*.log
```

### Permission Denied Errors

**Problem**: Cannot execute scripts

**Solution**:
```bash
chmod +x build.sh start-hadoop.sh run-mapreduce.sh
```

---

## <sub>Optional: Advanced Configuration</sub>

### <sub>Adjusting Memory Settings</sub>

<sub>If running on a system with limited RAM, edit `Dockerfile` and reduce memory allocations:</sub>

```dockerfile
<sub>
# In mapred-site.xml configuration section
<property><name>mapreduce.map.memory.mb</name><value>256</value></property>
<property><name>mapreduce.reduce.memory.mb</name><value>256</value></property>
<property><name>yarn.app.mapreduce.am.resource.mb</name><value>256</value></property>

# In yarn-site.xml configuration section
<property><name>yarn.nodemanager.resource.memory-mb</name><value>512</value></property>
<property><name>yarn.scheduler.maximum-allocation-mb</name><value>512</value></property>
</sub>
```

<sub>Then rebuild: `./build.sh`</sub>

### <sub>Persistent Data Storage</sub>

<sub>To persist HDFS data across container restarts:</sub>

```bash
<sub>
# Create volume
docker volume create hadoop-data

# Run with volume
docker run -d --name hadoop-cluster \
    -p 9870:9870 -p 8088:8088 -p 9000:9000 -p 9864:9864 \
    -v hadoop-data:/tmp/hadoop \
    hadoop:latest
</sub>
```

### <sub>Running Multiple Jobs</sub>

<sub>To process different datasets without restarting:</sub>

```bash
<sub>
# Job 1
cp dataset1.txt input.txt
./run-mapreduce.sh

# Job 2  
cp dataset2.txt input.txt
./run-mapreduce.sh

# Results are saved with timestamps in output/
</sub>
```

### <sub>Custom Output Directory</sub>

<sub>Modify the output path in `run-mapreduce.sh`:</sub>

```bash
<sub>
# Change this line:
hadoop MR_Demo.demo.DemoApplication /user/hadoop/input/input.txt /user/hadoop/output/sales-analysis

# To custom path:
hadoop MR_Demo.demo.DemoApplication /user/hadoop/input/input.txt /user/hadoop/output/my-custom-output
</sub>
```

### <sub>Viewing YARN Application Logs</sub>

```bash
<sub>
# Get application ID from ResourceManager UI or:
docker exec hadoop-cluster yarn application -list

# View logs (replace APP_ID)
docker exec hadoop-cluster yarn logs -applicationId application_XXXXXXXXXX_XXXX
</sub>
```

---

## Architecture & How It Works

### MapReduce Flow

```
Input File (CSV) → HDFS → Map Task → Shuffle & Sort → Reduce Task → Output
```

1. **Input**: Sales data uploaded to HDFS
2. **Map Phase**: Each line is processed to extract (company, price) pairs
3. **Shuffle**: Hadoop groups all prices by company
4. **Reduce Phase**: Sum prices for each company
5. **Output**: Final aggregated results written to HDFS

### Container Architecture

```
Docker Container
├── Ubuntu 20.04 Base
├── Java 11 Runtime
├── Hadoop 3.3.6
│   ├── HDFS (Distributed File System)
│   │   ├── NameNode (Port 9870)
│   │   └── DataNode (Port 9864)
│   └── YARN (Resource Manager)
│       ├── ResourceManager (Port 8088)
│       └── NodeManager
└── Your MapReduce Application (JAR)
```

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature-name`
5. Submit a pull request

---

## Acknowledgments

- Apache Hadoop community for the excellent distributed computing framework
- Docker for simplifying deployment and containerization

---

## Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [Docker logs](#container-wont-start)
3. Open an issue on GitHub with:
   - Your OS and Docker version
   - Complete error message
   - Steps to reproduce

---

## Version History

- **v1.0.0** (2025-01-01)
  - Initial release
  - Hadoop 3.3.6 support
  - Java 11 MapReduce implementation
  - Dockerized workflow
  - Automated build and execution scripts
