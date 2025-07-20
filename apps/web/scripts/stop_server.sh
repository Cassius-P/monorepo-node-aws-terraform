#!/bin/bash

# Stop Server Script for Next.js Web App
# This script gracefully stops the Next.js application

set -e

# For first deployment, there might be nothing to stop
if [[ ! -d "/opt/comptastar-web" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] First deployment detected, no application to stop" | tee -a "/var/log/codedeploy-stop.log"
    exit 0
fi

LOG_FILE="/var/log/codedeploy-stop.log"
APP_DIR="/opt/comptastar-web"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Stopping Next.js application server..."

# Check if PM2 is installed and running
if ! command -v pm2 &> /dev/null; then
    log "PM2 not found, assuming no application is running"
    exit 0
fi

# Check if the application is running
if ! pm2 list | grep -q "comptastar-web"; then
    log "Application is not running, nothing to stop"
    exit 0
fi

log "Found running application, proceeding with graceful shutdown..."

# Get application status before stopping
log "Current application status:"
pm2 status comptastar-web || true

# Gracefully stop the application
log "Gracefully stopping comptastar-web..."
pm2 stop comptastar-web 2>/dev/null || true

# Wait a moment for graceful shutdown
sleep 5

# Force stop if still running
if pm2 list | grep -q "comptastar-web.*online"; then
    log "Application still running, forcing stop..."
    pm2 kill comptastar-web 2>/dev/null || true
fi

# Delete the application from PM2
log "Removing application from PM2..."
pm2 delete comptastar-web 2>/dev/null || true

# Verify application is stopped
if pm2 list | grep -q "comptastar-web"; then
    log "WARNING: Application may still be registered in PM2"
    pm2 list
else
    log "Application successfully removed from PM2"
fi

# Clean up any remaining processes
log "Cleaning up any remaining Node.js processes..."
pkill -f "comptastar-web" 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true

# Clean up temporary files
log "Cleaning up temporary files..."
if [[ -d "$APP_DIR" ]]; then
    # Remove old .env.local file for security
    rm -f "$APP_DIR/.env.local" 2>/dev/null || true
    
    # Remove PM2 config
    rm -f "$APP_DIR/ecosystem.config.js" 2>/dev/null || true
    
    # Remove any temp files
    find "$APP_DIR" -name "*.tmp" -delete 2>/dev/null || true
fi

# Save PM2 configuration
pm2 save 2>/dev/null || true

log "Next.js application server stopped successfully!"

# Final verification
if pgrep -f "comptastar-web" > /dev/null; then
    log "WARNING: Some application processes may still be running"
    pgrep -f "comptastar-web" | while read -r pid; do
        log "  PID: $pid"
    done
else
    log "All application processes have been stopped"
fi

log "Stop operation completed!"