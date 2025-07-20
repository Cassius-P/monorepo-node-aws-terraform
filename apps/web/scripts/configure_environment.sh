#!/bin/bash

# Configure Environment Script for Next.js Web App
# This script configures environment variables using AWS Systems Manager

set -e

LOG_FILE="/var/log/codedeploy-configure.log"
APP_DIR="/opt/comptastar-web"
ENV_FILE="$APP_DIR/.env.local"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting environment configuration for Web app..."

# Change to application directory
cd "$APP_DIR"

# Ensure we have the env-manager script
if [[ ! -f "scripts/env-manager.sh" ]]; then
    log "ERROR: env-manager.sh script not found in $APP_DIR/scripts/"
    exit 1
fi

# Make env-manager script executable
chmod +x scripts/env-manager.sh

# Check if .env.example exists
if [[ ! -f ".env.example" ]]; then
    log "ERROR: .env.example file not found in $APP_DIR"
    exit 1
fi

log "Found .env.example file"

# Get environment from EC2 tags or use default
ENVIRONMENT=${CODEDEPLOY_DEPLOYMENT_GROUP_NAME:-prod}
log "Environment: $ENVIRONMENT"

# Validate AWS credentials and permissions
log "Validating AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log "ERROR: AWS credentials not configured or invalid"
    exit 1
fi

log "AWS credentials validated"

# Test SSM access
log "Testing AWS Systems Manager access..."
if ! aws ssm describe-parameters --max-items 1 > /dev/null 2>&1; then
    log "ERROR: Cannot access AWS Systems Manager. Check IAM permissions."
    exit 1
fi

log "AWS Systems Manager access confirmed"

# First, validate that all required parameters exist
log "Validating environment parameters..."
if ! ./scripts/env-manager.sh -a web -e "$ENVIRONMENT" -v; then
    log "ERROR: Environment validation failed. Some required parameters are missing."
    log "Please ensure all parameters are created in AWS Systems Manager Parameter Store"
    exit 1
fi

log "Environment validation passed"

# Generate .env.local file from AWS Systems Manager
log "Generating .env.local file from AWS Systems Manager..."
if ! ./scripts/env-manager.sh -a web -e "$ENVIRONMENT" -o "$ENV_FILE"; then
    log "ERROR: Failed to generate .env.local file"
    exit 1
fi

log "Successfully generated .env.local file"

# Verify .env.local file was created and has content
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: .env.local file was not created"
    exit 1
fi

if [[ ! -s "$ENV_FILE" ]]; then
    log "ERROR: .env.local file is empty"
    exit 1
fi

# Log environment variables (without values for security)
log "Environment variables configured:"
grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | cut -d'=' -f1 | while read -r var; do
    log "  - $var"
done

# Set proper permissions on .env.local file
chmod 600 "$ENV_FILE"
chown ec2-user:ec2-user "$ENV_FILE"

log "Environment configuration completed successfully!"

# Validate critical environment variables
log "Validating critical environment variables..."
source "$ENV_FILE"

if [[ -z "$NEXT_PORT" ]]; then
    log "ERROR: NEXT_PORT environment variable is not set"
    exit 1
fi

log "NEXT_PORT is set to: $NEXT_PORT"

log "Environment configuration validation completed!"