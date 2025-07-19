#!/bin/bash

# Configure Environment Script for CodeDeploy
# This script configures environment variables using AWS Systems Manager

set -e

LOG_FILE="/var/log/codedeploy-configure.log"
APP_DIR="/opt/comptastar-api"
ENV_FILE="$APP_DIR/.env"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting environment configuration..."

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
if ! ./scripts/env-manager.sh -a api -e "$ENVIRONMENT" -v; then
    log "ERROR: Environment validation failed. Some required parameters are missing."
    log "Please ensure all parameters are created in AWS Systems Manager Parameter Store"
    exit 1
fi

log "Environment validation passed"

# Generate .env file from AWS Systems Manager
log "Generating .env file from AWS Systems Manager..."
if ! ./scripts/env-manager.sh -a api -e "$ENVIRONMENT" -o "$ENV_FILE"; then
    log "ERROR: Failed to generate .env file"
    exit 1
fi

log "Successfully generated .env file"

# Verify .env file was created and has content
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: .env file was not created"
    exit 1
fi

if [[ ! -s "$ENV_FILE" ]]; then
    log "ERROR: .env file is empty"
    exit 1
fi

# Log environment variables (without values for security)
log "Environment variables configured:"
grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | cut -d'=' -f1 | while read -r var; do
    log "  - $var"
done

# Set proper permissions on .env file
chmod 600 "$ENV_FILE"
chown ec2-user:ec2-user "$ENV_FILE"

log "Environment configuration completed successfully!"

# Validate critical environment variables
log "Validating critical environment variables..."
source "$ENV_FILE"

if [[ -z "$NEST_PORT" ]]; then
    log "ERROR: NEST_PORT environment variable is not set"
    exit 1
fi

log "NEST_PORT is set to: $NEST_PORT"

log "Environment configuration validation completed!"