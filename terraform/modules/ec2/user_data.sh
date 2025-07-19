#!/bin/bash

# User Data Script for EC2 instances
# This script runs when the instance first starts

# Update system
yum update -y

# Install basic tools
yum install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    awscli

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/codedeploy-*.log",
            "log_group_name": "/aws/ec2/${project_name}/${environment}",
            "log_stream_name": "{instance_id}/codedeploy"
          },
          {
            "file_path": "/var/log/comptastar-${app_name}/*.log",
            "log_group_name": "/aws/ec2/${project_name}/${environment}/${app_name}",
            "log_stream_name": "{instance_id}/application"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/${environment}",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Install CodeDeploy agent
yum install -y ruby
cd /home/ec2-user
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Start CodeDeploy agent
service codedeploy-agent start
chkconfig codedeploy-agent on

# Create application directories
mkdir -p /opt/comptastar-${app_name}
mkdir -p /var/log/comptastar-${app_name}
chown ec2-user:ec2-user /opt/comptastar-${app_name}
chown ec2-user:ec2-user /var/log/comptastar-${app_name}

# Signal that the instance is ready
/opt/aws/bin/cfn-signal -e $? --stack ${project_name}-${environment} --region us-east-1 --resource AutoScalingGroup || true

echo "User data script completed successfully!"