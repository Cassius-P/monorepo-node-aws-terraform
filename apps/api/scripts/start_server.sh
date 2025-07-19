#!/bin/bash

# Start Server Script for CodeDeploy
# This script starts the NestJS application using PM2

set -e

LOG_FILE="/var/log/codedeploy-start.log"
APP_DIR="/opt/comptastar-api"
ENV_FILE="$APP_DIR/.env"
PM2_CONFIG="$APP_DIR/ecosystem.config.js"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting application server..."

# Change to application directory
cd "$APP_DIR"

# Verify .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

log "Environment variables loaded"

# Verify required variables
if [[ -z "$NEST_PORT" ]]; then
    log "ERROR: NEST_PORT environment variable is not set"
    exit 1
fi

log "Application will start on port: $NEST_PORT"

# Install production dependencies if needed
log "Installing production dependencies..."
if [[ -f "package.json" ]]; then
    pnpm install --prod --frozen-lockfile
else
    log "ERROR: package.json not found"
    exit 1
fi

# Create PM2 ecosystem configuration
log "Creating PM2 configuration..."
cat > "$PM2_CONFIG" << EOF
module.exports = {
  apps: [{
    name: 'comptastar-api',
    script: 'dist/main.js',
    cwd: '$APP_DIR',
    instances: 1,
    exec_mode: 'fork',
    env_file: '$ENV_FILE',
    log_file: '/var/log/comptastar-api/app.log',
    out_file: '/var/log/comptastar-api/app.out.log',
    error_file: '/var/log/comptastar-api/app.error.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    watch: false,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      NEST_PORT: '$NEST_PORT'
    }
  }]
};
EOF

log "PM2 configuration created"

# Stop any existing PM2 processes
log "Stopping any existing application processes..."
pm2 stop comptastar-api 2>/dev/null || true
pm2 delete comptastar-api 2>/dev/null || true

# Start the application with PM2
log "Starting application with PM2..."
pm2 start "$PM2_CONFIG"

# Wait for application to start
log "Waiting for application to start..."
sleep 10

# Check if application is running
if ! pm2 list | grep -q "comptastar-api.*online"; then
    log "ERROR: Application failed to start"
    pm2 logs comptastar-api --lines 50
    exit 1
fi

log "Application started successfully"

# Perform health check
log "Performing application health check..."
HEALTH_CHECK_URL="http://localhost:$NEST_PORT/api/v1/health"
MAX_ATTEMPTS=30
ATTEMPT=1

while [[ $ATTEMPT -le $MAX_ATTEMPTS ]]; do
    log "Health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    if curl -f -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        log "Health check passed!"
        break
    fi
    
    if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
        log "ERROR: Health check failed after $MAX_ATTEMPTS attempts"
        log "Application logs:"
        pm2 logs comptastar-api --lines 20
        exit 1
    fi
    
    sleep 5
    ((ATTEMPT++))
done

# Display application status
log "Application status:"
pm2 status comptastar-api

# Save PM2 configuration for auto-restart
pm2 save

log "Application server started successfully!"

# Log application URL
log "Application is available at: http://localhost:$NEST_PORT/api/v1/health"