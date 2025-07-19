#!/bin/bash

# Parameter Setup Helper Script
# This script helps create AWS Systems Manager parameters from .env.example files

set -e

# Configuration
DEFAULT_ENVIRONMENT="prod"
DEFAULT_APP_PREFIX=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script helps set up AWS Systems Manager parameters for applications"
    echo "by parsing .env.example files and generating AWS CLI commands."
    echo ""
    echo "Options:"
    echo "  -a, --app APP_NAME        Application name (required)"
    echo "  -e, --env ENVIRONMENT     Environment (default: prod)"
    echo "  -p, --prefix PREFIX       SSM parameter prefix (default: none)"
    echo "  -c, --create             Actually create parameters (default: dry-run)"
    echo "  -f, --force              Overwrite existing parameters"
    echo "  -t, --type TYPE          Parameter type: String|SecureString (default: String)"
    echo "  -v, --value-prompt       Prompt for each parameter value interactively"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -a api                                   # Show commands for api app (dry-run)"
    echo "  $0 -a api -c                               # Create parameters for api app"
    echo "  $0 -a api -v -c                            # Create parameters with interactive prompts"
    echo "  $0 -a api -e staging -f -c                 # Create/overwrite staging parameters"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
}

# Parse .env.example file and extract variable names and default values
parse_env_example() {
    local env_example_file="$1"
    
    if [[ ! -f "$env_example_file" ]]; then
        log_error ".env.example file not found: $env_example_file"
        exit 1
    fi
    
    # Extract variable names and values (lines that don't start with # and contain =)
    grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$env_example_file" | while IFS='=' read -r var_name var_value; do
        echo "$var_name|$var_value"
    done
}

# Check if parameter exists
parameter_exists() {
    local parameter_path="$1"
    
    aws ssm get-parameter --name "$parameter_path" > /dev/null 2>&1
    return $?
}

# Create parameter
create_parameter() {
    local parameter_path="$1"
    local parameter_value="$2"
    local parameter_type="$3"
    local overwrite="$4"
    
    local overwrite_flag=""
    if [[ "$overwrite" == "true" ]]; then
        overwrite_flag="--overwrite"
    fi
    
    if aws ssm put-parameter \
        --name "$parameter_path" \
        --value "$parameter_value" \
        --type "$parameter_type" \
        --description "Parameter for application deployment" \
        $overwrite_flag > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Prompt for parameter value
prompt_for_value() {
    local var_name="$1"
    local default_value="$2"
    local prompt_text
    
    if [[ -n "$default_value" ]]; then
        prompt_text="Enter value for $var_name (default: $default_value): "
    else
        prompt_text="Enter value for $var_name: "
    fi
    
    read -p "$prompt_text" input_value
    
    if [[ -z "$input_value" && -n "$default_value" ]]; then
        echo "$default_value"
    else
        echo "$input_value"
    fi
}

# Main function
main() {
    local app_name=""
    local environment="$DEFAULT_ENVIRONMENT"
    local prefix="$DEFAULT_APP_PREFIX"
    local create_params=false
    local force_overwrite=false
    local parameter_type="String"
    local value_prompt=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--app)
                app_name="$2"
                shift 2
                ;;
            -e|--env)
                environment="$2"
                shift 2
                ;;
            -p|--prefix)
                prefix="$2"
                shift 2
                ;;
            -c|--create)
                create_params=true
                shift
                ;;
            -f|--force)
                force_overwrite=true
                shift
                ;;
            -t|--type)
                parameter_type="$2"
                shift 2
                ;;
            -v|--value-prompt)
                value_prompt=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$app_name" ]]; then
        log_error "Application name is required"
        usage
        exit 1
    fi
    
    # Validate parameter type
    if [[ "$parameter_type" != "String" && "$parameter_type" != "SecureString" ]]; then
        log_error "Parameter type must be 'String' or 'SecureString'"
        exit 1
    fi
    
    # Check dependencies
    check_aws_cli
    
    # Find .env.example file
    local env_example_file="$PROJECT_ROOT/apps/$app_name/.env.example"
    
    if [[ ! -f "$env_example_file" ]]; then
        log_error ".env.example file not found: $env_example_file"
        exit 1
    fi
    
    log_info "Processing .env.example file: $env_example_file"
    log_info "Environment: $environment"
    log_info "Parameter prefix: $prefix"
    log_info "Parameter type: $parameter_type"
    
    if [[ "$create_params" == true ]]; then
        log_info "Mode: CREATE parameters"
    else
        log_info "Mode: DRY-RUN (showing commands only)"
    fi
    
    echo ""
    
    local created_count=0
    local skipped_count=0
    local failed_count=0
    
    # Process each variable from .env.example
    while IFS='|' read -r var_name var_value; do
        local parameter_path="/$environment/$app_name/$var_name"
        local final_value="$var_value"
        
        # Prompt for value if requested
        if [[ "$value_prompt" == true ]]; then
            final_value=$(prompt_for_value "$var_name" "$var_value")
        fi
        
        # Generate AWS CLI command
        local aws_command="aws ssm put-parameter --name \"$parameter_path\" --value \"$final_value\" --type $parameter_type"
        
        if [[ "$create_params" == false ]]; then
            # Dry-run mode: just show the command
            echo "$aws_command"
            continue
        fi
        
        # Check if parameter exists
        if parameter_exists "$parameter_path"; then
            if [[ "$force_overwrite" == true ]]; then
                log_info "Overwriting existing parameter: $var_name"
                if create_parameter "$parameter_path" "$final_value" "$parameter_type" "true"; then
                    log_success "✓ Updated: $var_name"
                    ((created_count++))
                else
                    log_error "✗ Failed to update: $var_name"
                    ((failed_count++))
                fi
            else
                log_warning "✓ Skipped (exists): $var_name"
                ((skipped_count++))
            fi
        else
            log_info "Creating new parameter: $var_name"
            if create_parameter "$parameter_path" "$final_value" "$parameter_type" "false"; then
                log_success "✓ Created: $var_name"
                ((created_count++))
            else
                log_error "✗ Failed to create: $var_name"
                ((failed_count++))
            fi
        fi
        
    done < <(parse_env_example "$env_example_file")
    
    # Summary
    if [[ "$create_params" == true ]]; then
        echo ""
        log_info "Summary:"
        log_success "Created/Updated: $created_count"
        log_warning "Skipped: $skipped_count"
        if [[ $failed_count -gt 0 ]]; then
            log_error "Failed: $failed_count"
        fi
        
        if [[ $failed_count -eq 0 ]]; then
            log_success "All parameters processed successfully!"
        else
            log_error "Some parameters failed to process"
            exit 1
        fi
    else
        echo ""
        log_info "To create these parameters, run the script with -c flag"
        log_info "To prompt for values interactively, add -v flag"
        log_info "To overwrite existing parameters, add -f flag"
    fi
}

# Run main function with all arguments
main "$@"