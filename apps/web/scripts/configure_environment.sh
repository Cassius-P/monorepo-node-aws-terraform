#!/bin/bash

# Wrapper script for Web app configuration
# This calls the generic configure_environment.sh script with app-specific parameters

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call the generic script with Web parameters (.env.local for Next.js)
# The generic script will be copied to the scripts directory during build
"$(dirname "$SCRIPT_DIR")/scripts/configure_environment_generic.sh" web .env.local