#!/bin/bash

# Wrapper script for API app configuration
# This calls the generic configure_environment.sh script with app-specific parameters

set -e

# Call the generic script with API parameters
/opt/server-scripts/configure_environment.sh api