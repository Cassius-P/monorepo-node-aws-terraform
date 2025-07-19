#!/bin/bash

# Install Dependencies Script for Next.js Web App
# This script installs all required dependencies on the EC2 instance

set -e

LOG_FILE="/var/log/codedeploy-install.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting dependency installation for Web app..."

# Update system packages
log "Updating system packages..."
sudo yum update -y

# Install Node.js 22 using NodeSource repository
log "Installing Node.js 22..."
if ! command -v node &> /dev/null || [[ $(node --version | cut -d'v' -f2 | cut -d'.' -f1) -lt 22 ]]; then
    log "Node.js 22 not found or outdated, installing..."
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
    sudo yum install -y nodejs
else
    log "Node.js 22 already installed"
fi

# Verify Node.js installation
node_version=$(node --version)
log "Node.js version: $node_version"

# Install pnpm globally
log "Installing pnpm..."
if ! command -v pnpm &> /dev/null; then
    sudo npm install -g pnpm@10.12.1
else
    log "pnpm already installed"
fi

# Verify pnpm installation
pnpm_version=$(pnpm --version)
log "pnpm version: $pnpm_version"

# Install PM2 globally for process management
log "Installing PM2..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    # Configure PM2 to start on boot
    sudo pm2 startup systemd -u ec2-user --hp /home/ec2-user
else
    log "PM2 already installed"
fi

# Verify PM2 installation
pm2_version=$(pm2 --version)
log "PM2 version: $pm2_version"

# Install AWS CLI v2 if not present
log "Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
else
    log "AWS CLI already installed"
fi

# Verify AWS CLI installation
aws_version=$(aws --version)
log "AWS CLI version: $aws_version"

# Create application directory if it doesn't exist
APP_DIR="/opt/comptastar-web"
log "Creating application directory: $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown ec2-user:ec2-user "$APP_DIR"

# Create logs directory
LOGS_DIR="/var/log/comptastar-web"
log "Creating logs directory: $LOGS_DIR"
sudo mkdir -p "$LOGS_DIR"
sudo chown ec2-user:ec2-user "$LOGS_DIR"

# Install additional system dependencies if needed
log "Installing additional system dependencies..."
sudo yum install -y \
    git \
    curl \
    wget \
    unzip \
    htop

log "Dependency installation completed successfully!"