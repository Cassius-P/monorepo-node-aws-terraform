#!/bin/bash
set -eux

##############################################################################
# 1. Update AMI and install base packages
##############################################################################
dnf update -y
# Install packages, handling curl conflict with curl-minimal
dnf install -y wget unzip git tar xz ruby --allowerasing
dnf install -y curl --allowerasing || true

##############################################################################
# 2. Create application user & directories
##############################################################################
useradd -m -s /bin/bash nodeapp || true             # non-blocking if already exists
APP_DIR=/opt/comptastar-${app_name}
mkdir -p "$APP_DIR"
mkdir -p /var/log/comptastar-${app_name}
chown nodeapp:nodeapp "$APP_DIR"
chown nodeapp:nodeapp /var/log/comptastar-${app_name}

##############################################################################
# 3. Install Node.js 22 and package managers
##############################################################################
# Install Node.js 22 from NodeSource
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
dnf install -y nodejs

# Install pnpm globally
npm install -g pnpm@10.12.1

# Install PM2 for process management
npm install -g pm2

##############################################################################
# 4. Configure PM2 service for systemd
##############################################################################
# Configure PM2 to start on boot
pm2 startup systemd -u nodeapp --hp /home/nodeapp

##############################################################################
# 5. Install and start CodeDeploy agent
##############################################################################
cd /home/ec2-user
wget https://aws-codedeploy-${aws_region}.s3.${aws_region}.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Start and enable CodeDeploy agent
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

##############################################################################
# 6. Install CloudWatch agent
##############################################################################
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
dnf install -y ./amazon-cloudwatch-agent.rpm

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

# End
echo "User data script completed successfully!"
exit 0