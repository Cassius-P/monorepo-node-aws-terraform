#!/usr/bin/env python3
"""
Parameter Setup Helper Script for AWS Systems Manager
This script helps create AWS Systems Manager parameters from .env.example files
"""

import argparse
import os
import sys
import re
import subprocess
import json
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def log_info(message: str):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def log_success(message: str):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def log_warning(message: str):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {message}")

def log_error(message: str):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")

def check_aws_cli() -> bool:
    """Check if AWS CLI is available and configured"""
    try:
        # Check if AWS CLI is installed
        subprocess.run(['aws', '--version'], capture_output=True, check=True)
        
        # Check if AWS credentials are configured
        result = subprocess.run(['aws', 'sts', 'get-caller-identity'], 
                               capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        log_error("AWS CLI is not installed or not configured properly")
        return False
    except FileNotFoundError:
        log_error("AWS CLI is not installed or not in PATH")
        return False

def parse_env_example(env_file_path: Path) -> List[Tuple[str, str]]:
    """Parse .env.example file and extract variable names and values"""
    if not env_file_path.exists():
        log_error(f".env.example file not found: {env_file_path}")
        sys.exit(1)
    
    variables = []
    # Regex pattern to match environment variable declarations
    env_var_pattern = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
    
    try:
        with open(env_file_path, 'r', encoding='utf-8') as file:
            for line_num, line in enumerate(file, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                match = env_var_pattern.match(line)
                if match:
                    var_name = match.group(1)
                    var_value = match.group(2)
                    # Remove quotes if present
                    if var_value.startswith('"') and var_value.endswith('"'):
                        var_value = var_value[1:-1]
                    elif var_value.startswith("'") and var_value.endswith("'"):
                        var_value = var_value[1:-1]
                    
                    variables.append((var_name, var_value))
                    log_info(f"Found variable: {var_name}")
    
    except Exception as e:
        log_error(f"Error reading {env_file_path}: {e}")
        sys.exit(1)
    
    return variables

def parameter_exists(parameter_path: str) -> bool:
    """Check if a parameter exists in AWS SSM"""
    try:
        subprocess.run(['aws', 'ssm', 'get-parameter', '--name', parameter_path],
                      capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def create_parameter(parameter_path: str, parameter_value: str, 
                    parameter_type: str, overwrite: bool = False) -> bool:
    """Create or update a parameter in AWS SSM"""
    cmd = [
        'aws', 'ssm', 'put-parameter',
        '--name', parameter_path,
        '--value', parameter_value,
        '--type', parameter_type,
        '--description', 'Parameter for application deployment'
    ]
    
    if overwrite:
        cmd.append('--overwrite')
    
    try:
        subprocess.run(cmd, capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        log_error(f"Failed to create parameter {parameter_path}: {e.stderr.decode() if e.stderr else 'Unknown error'}")
        return False

def infer_type_from_value(value: str) -> str:
    """Infer the data type from the value"""
    if not value:
        return "String"
    
    # Try to determine if it's an integer
    try:
        int(value)
        return "Integer"
    except ValueError:
        pass
    
    # Try to determine if it's a float
    try:
        float(value)
        return "Float"
    except ValueError:
        pass
    
    # Check for boolean values
    if value.lower() in ('true', 'false'):
        return "Boolean"
    
    # Check for URL patterns
    if value.startswith(('http://', 'https://', 'ftp://', 'ws://', 'wss://')):
        return "URL"
    
    # Check for email patterns
    if '@' in value and '.' in value.split('@')[1]:
        return "Email"
    
    # Default to String
    return "String"

def prompt_for_value_with_type(var_name: str, example_value: str) -> str:
    """Prompt user for parameter value with type inference and example"""
    inferred_type = infer_type_from_value(example_value)
    
    if example_value:
        prompt = f"{var_name}[{inferred_type}] (eg: {example_value}): "
    else:
        prompt = f"{var_name}[{inferred_type}]: "
    
    while True:
        user_input = input(prompt).strip()
        
        if not user_input:
            log_warning("Value cannot be empty. Please enter a value.")
            continue
            
        return user_input

def main():
    parser = argparse.ArgumentParser(
        description="Set up AWS Systems Manager parameters from .env.example files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -a api                                   # Dry run - show what parameters would be created
  %(prog)s -a api -c                               # Create parameters with user prompts (no default values)
  %(prog)s -a api -cf                              # Create parameters using .env.example values directly
  %(prog)s -a api -e staging                       # Dry run for staging environment
        """
    )
    
    parser.add_argument('-a', '--app', required=True,
                       help='Application name (required)')
    parser.add_argument('-e', '--env', default='prod',
                       help='Environment (default: prod)')
    parser.add_argument('-c', '--create', action='store_true',
                       help='Create parameters with interactive prompts')
    parser.add_argument('-f', '--force', action='store_true',
                       help='When used with -c: use .env.example values directly (no prompts). When used alone: overwrite existing parameters')
    parser.add_argument('-t', '--type', default='String',
                       choices=['String', 'SecureString'],
                       help='Parameter type (default: String)')
    
    # Remove old arguments that are no longer needed
    # parser.add_argument('-p', '--prefix', default='', help='SSM parameter prefix (default: none)')
    # parser.add_argument('-v', '--value-prompt', action='store_true', help='Prompt for each parameter value interactively')
    
    args = parser.parse_args()
    
    # Validate parameter type
    if args.type not in ['String', 'SecureString']:
        log_error("Parameter type must be 'String' or 'SecureString'")
        sys.exit(1)
    
    # Check AWS CLI
    if not check_aws_cli():
        sys.exit(1)
    
    # Find project root and .env.example file
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    env_file_path = project_root / 'apps' / args.app / '.env.example'
    
    if not env_file_path.exists():
        log_error(f".env.example file not found: {env_file_path}")
        sys.exit(1)
    
    log_info(f"Processing .env.example file: {env_file_path}")
    log_info(f"Environment: {args.env}")
    log_info(f"Parameter type: {args.type}")
    
    # Determine mode based on arguments
    if not args.create:
        mode = "DRY-RUN"
        log_info("Mode: DRY-RUN (showing what parameters would be created)")
    elif args.create and args.force:
        mode = "CREATE_WITH_DEFAULTS"
        log_info("Mode: CREATE parameters using .env.example values")
    elif args.create:
        mode = "CREATE_WITH_PROMPTS"
        log_info("Mode: CREATE parameters with interactive prompts")
    
    print()
    
    # Parse environment variables
    variables = parse_env_example(env_file_path)
    
    if not variables:
        log_warning("No environment variables found in .env.example file")
        return
    
    # Process each variable
    created_count = 0
    skipped_count = 0
    failed_count = 0
    
    for var_name, var_value in variables:
        parameter_path = f"/{args.env}/{args.app}/{var_name}"
        final_value = var_value
        
        # Handle different modes
        if mode == "DRY-RUN":
            # Show what would be created
            aws_command = f'aws ssm put-parameter --name "{parameter_path}" --value "{final_value}" --type {args.type}'
            print(aws_command)
            continue
        elif mode == "CREATE_WITH_PROMPTS":
            # Prompt user for value with type inference and examples
            final_value = prompt_for_value_with_type(var_name, var_value)
        elif mode == "CREATE_WITH_DEFAULTS":
            # Use the value from .env.example directly
            final_value = var_value
            log_info(f"Using default value for {var_name}: {final_value}")
        
        # Check if parameter exists
        if parameter_exists(parameter_path):
            if args.force or mode == "CREATE_WITH_DEFAULTS":
                log_info(f"Overwriting existing parameter: {var_name}")
                if create_parameter(parameter_path, final_value, args.type, overwrite=True):
                    log_success(f"✓ Updated: {var_name}")
                    created_count += 1
                else:
                    log_error(f"✗ Failed to update: {var_name}")
                    failed_count += 1
            else:
                log_warning(f"✓ Skipped (exists): {var_name}")
                log_info(f"Use -f flag to overwrite existing parameters")
                skipped_count += 1
        else:
            log_info(f"Creating new parameter: {var_name}")
            if create_parameter(parameter_path, final_value, args.type, overwrite=False):
                log_success(f"✓ Created: {var_name}")
                created_count += 1
            else:
                log_error(f"✗ Failed to create: {var_name}")
                failed_count += 1
    
    # Summary
    if mode != "DRY-RUN":
        print()
        log_info("Summary:")
        log_success(f"Created/Updated: {created_count}")
        log_warning(f"Skipped: {skipped_count}")
        if failed_count > 0:
            log_error(f"Failed: {failed_count}")
        
        if failed_count == 0:
            log_success("All parameters processed successfully!")
        else:
            log_error("Some parameters failed to process")
            sys.exit(1)
    else:
        print()
        log_info("Available options:")
        log_info("  -c    : Create parameters with interactive prompts")
        log_info("  -cf   : Create parameters using .env.example values directly")

if __name__ == "__main__":
    main()