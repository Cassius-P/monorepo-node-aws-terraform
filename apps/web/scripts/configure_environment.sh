#!/bin/bash

# Wrapper script for Web app configuration
# This calls the generic configure_environment.sh script with app-specific parameters

set -e

# Call the generic script with Web parameters (.env.local for Next.js)
/opt/server-scripts/configure_environment.sh web .env.local