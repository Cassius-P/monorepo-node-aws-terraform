#!/bin/bash

# Generic Configure Environment Script for CodeDeploy
# This script configures environment variables using AWS Systems Manager
# Usage: configure_environment.sh <app_name> [env_file_name]

set -e

# Check if app name is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app_name> [env_file_name]"
    echo "Example: $0 api"
    echo "Example: $0 web .env.local"
    exit 1
fi

APP_NAME="$1"
ENV_FILE_NAME="${2:-.env}"  # Default to .env if not specified

LOG_FILE="/var/log/codedeploy-configure.log"
APP_DIR="/opt/comptastar-${APP_NAME}"
ENV_FILE="$APP_DIR/$ENV_FILE_NAME"

# Create log file with proper permissions if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/codedeploy-configure.log"
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting environment configuration for app: $APP_NAME"

# Change to application directory
cd "$APP_DIR"

# Debug: Show current directory and contents
log "Current working directory: $(pwd)"
log "Directory contents:"
ls -la | while read -r line; do
    log "  $line"
done

# Ensure we have the env-manager script
if [[ ! -f "scripts/env-manager.sh" ]]; then
    log "ERROR: env-manager.sh script not found in $APP_DIR/scripts/"
    exit 1
fi

# Make env-manager script executable
chmod +x scripts/env-manager.sh

# Check if .env.example exists
if [[ ! -f ".env.example" ]]; then
    log "WARNING: .env.example file not found in $APP_DIR"
    log "Skipping env-manager validation and proceeding with direct parameter fetch"
    # Skip to direct parameter generation without validation
    SKIP_VALIDATION=true
else
    log "Found .env.example file"
    SKIP_VALIDATION=false
fi

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
log "Current IAM identity: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo 'Unable to get identity')"
log "Environment value: '$ENVIRONMENT'"
log "Testing access to path: /$ENVIRONMENT/$APP_NAME/"
if ! aws ssm get-parameters-by-path --path "/$ENVIRONMENT/$APP_NAME/" > /dev/null 2>&1; then
    log "ERROR: Cannot access AWS Systems Manager path /$ENVIRONMENT/$APP_NAME/. Check IAM permissions."
    exit 1
fi

log "AWS Systems Manager access confirmed"

# First, validate that all required parameters exist (only if .env.example exists)
if [[ "$SKIP_VALIDATION" == "false" ]]; then
    log "Validating environment parameters..."
    log "Looking for .env.example in: $(pwd)/.env.example"
    ls -la .env.example 2>/dev/null && log "Found .env.example file for validation" || log "Cannot access .env.example file"
    
    if ! ./scripts/env-manager.sh -a "$APP_NAME" -e "$ENVIRONMENT" -v; then
        log "ERROR: Environment validation failed. Some required parameters are missing."
        log "Please ensure all parameters are created in AWS Systems Manager Parameter Store"
        exit 1
    fi
    log "Environment validation passed"
else
    log "Skipping parameter validation due to missing .env.example file"
fi

# Generate .env file from AWS Systems Manager
log "Generating $ENV_FILE_NAME file from AWS Systems Manager..."
if [[ "$SKIP_VALIDATION" == "false" ]]; then
    # Use env-manager.sh when .env.example is available
    if ! ./scripts/env-manager.sh -a "$APP_NAME" -e "$ENVIRONMENT" -o "$ENV_FILE"; then
        log "ERROR: Failed to generate $ENV_FILE_NAME file using env-manager.sh"
        exit 1
    fi
else
    # Direct AWS SSM parameter fetch when .env.example is missing
    log "Using direct AWS SSM parameter fetch..."
    aws ssm get-parameters-by-path \
        --path "/$ENVIRONMENT/$APP_NAME/" \
        --recursive \
        --with-decryption \
        --query 'Parameters[*].[Name,Value]' \
        --output text | while read -r name value; do
        # Extract parameter name (remove path prefix)
        param_name="${name##*/}"
        echo "${param_name}=${value}" >> "$ENV_FILE"
    done
    
    if [[ ! -s "$ENV_FILE" ]]; then
        log "ERROR: No parameters found for /$ENVIRONMENT/$APP_NAME/"
        exit 1
    fi
fi

log "Successfully generated $ENV_FILE_NAME file"

# Verify .env file was created and has content
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: $ENV_FILE_NAME file was not created"
    exit 1
fi

if [[ ! -s "$ENV_FILE" ]]; then
    log "ERROR: $ENV_FILE_NAME file is empty"
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

log "Environment configuration completed successfully for $APP_NAME!"