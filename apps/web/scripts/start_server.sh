#!/bin/bash

# Start Server Script for Next.js Web App
# This script starts the Next.js application using PM2

set -e

LOG_FILE="/var/log/codedeploy-start.log"
APP_DIR="/opt/comptastar-web"
ENV_FILE="$APP_DIR/.env.local"
PM2_CONFIG="$APP_DIR/ecosystem.config.js"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Next.js application server..."

# Change to application directory
cd "$APP_DIR"

# Verify .env.local file exists
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR: .env.local file not found at $ENV_FILE"
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

log "Environment variables loaded"

# Verify required variables
if [[ -z "$NEXT_PORT" ]]; then
    log "ERROR: NEXT_PORT environment variable is not set"
    exit 1
fi

log "Application will start on port: $NEXT_PORT"

# Install production dependencies if needed
log "Installing production dependencies..."
if [[ -f "package.json" ]]; then
    # Ensure pnpm is available in PATH
    export PATH="/usr/local/node/bin:$PATH"
    pnpm install --prod --no-frozen-lockfile || {
        log "pnpm install failed, trying with npm..."
        npm install --production --no-package-lock
    }
else
    log "ERROR: package.json not found"
    exit 1
fi

# Create PM2 ecosystem configuration
log "Creating PM2 configuration..."
cat > "$PM2_CONFIG" << EOF
module.exports = {
  apps: [{
    name: 'comptastar-web',
    script: 'node_modules/.bin/next',
    args: 'start',
    cwd: '$APP_DIR',
    instances: 1,
    exec_mode: 'fork',
    env_file: '$ENV_FILE',
    log_file: '/var/log/comptastar-web/app.log',
    out_file: '/var/log/comptastar-web/app.out.log',
    error_file: '/var/log/comptastar-web/app.error.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    watch: false,
    autorestart: true,
    env: {
      NODE_ENV: 'production',
      PORT: '$NEXT_PORT',
      NEXT_PORT: '$NEXT_PORT'
    }
  }]
};
EOF

log "PM2 configuration created"

# Stop any existing PM2 processes
log "Stopping any existing application processes..."
pm2 stop comptastar-web 2>/dev/null || true
pm2 delete comptastar-web 2>/dev/null || true

# Start the application with PM2
log "Starting application with PM2..."
pm2 start "$PM2_CONFIG"

# Wait for application to start
log "Waiting for application to start..."
sleep 15

# Check if application is running
if ! pm2 list | grep -q "comptastar-web.*online"; then
    log "ERROR: Application failed to start"
    pm2 logs comptastar-web --lines 50
    exit 1
fi

log "Application started successfully"

# Perform health check
log "Performing application health check..."
HEALTH_CHECK_URL="http://localhost:$NEXT_PORT/api/health"
MAX_ATTEMPTS=30
ATTEMPT=1

while [[ $ATTEMPT -le $MAX_ATTEMPTS ]]; do
    log "Health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # Check the dedicated health endpoint
    if curl -f -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        log "Health check passed! API endpoint is responding."
        break
    fi
    
    if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
        log "ERROR: Health check failed after $MAX_ATTEMPTS attempts"
        log "Application logs:"
        pm2 logs comptastar-web --lines 20
        exit 1
    fi
    
    sleep 5
    ((ATTEMPT++))
done

# Display application status
log "Application status:"
pm2 status comptastar-web

# Save PM2 configuration for auto-restart
pm2 save

log "Next.js application server started successfully!"

# Log application URL
log "Application is available at: http://localhost:$NEXT_PORT"