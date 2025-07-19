# Terraform Infrastructure Guide

This guide explains how to deploy, manage, and undeploy the AWS infrastructure for the ComptaStar monorepo using Terraform.

## Architecture Overview

The infrastructure supports multiple applications with independent CI/CD pipelines:
- **API Application** (NestJS) - Port 3001, path `/apps/api/`
- **Web Application** (Next.js) - Port 3000, path `/apps/web/`

Each application has its own:
- Application Load Balancer with blue-green deployment
- Auto Scaling Groups for high availability
- CodePipeline for CI/CD automation
- CodeBuild for building applications
- CodeDeploy for blue-green deployments

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** version 1.5.0 or later
3. **GitHub repository** with the monorepo code
4. **AWS Key Pair** for EC2 instances
5. **GitHub App Connection** configured in AWS CodeStar

### Required AWS Permissions

Your AWS user/role needs permissions for:
- VPC, EC2, ALB, Auto Scaling
- CodePipeline, CodeBuild, CodeDeploy
- IAM roles and policies
- CloudWatch logs and alarms
- Systems Manager Parameter Store
- CodeStar Connections (for GitHub App integration)

## Environment Variables Setup

Before deploying, set up environment variables in AWS Systems Manager Parameter Store:

```bash
# 1. Dry run - see what parameters would be created (recommended first step)
./scripts/setup-parameters.py -a api

# 2. Create parameters with interactive prompts (shows types and examples)
./scripts/setup-parameters.py -a api -c

# 3. Create parameters using .env.example values directly (no prompts)
./scripts/setup-parameters.py -a api -cf

# Or manually create parameters using AWS CLI:
aws ssm put-parameter \
  --name "/prod/api/NEST_PORT" \
  --value "3001" \
  --type "String" \
  --description "NestJS API port"
```

Parameter naming convention: `/{environment}/{app_name}/{parameter_name}`

## Deployment

### 1. Initial Setup

```bash
# Navigate to production environment
cd terraform/environments/prod

# Initialize Terraform
terraform init

# Validate configuration
terraform validate
```

### 2. Configure Variables

Create `terraform.tfvars` file:

```hcl
# Required variables
key_pair_name = "your-ec2-key-pair-name"
source_repository_url = "https://github.com/your-username/your-repo.git"
github_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/12345678-1234-1234-1234-123456789012"

# Optional overrides
aws_region = "us-east-1"
environment = "prod"

# Application configuration (optional - defaults provided)
applications = {
  api = {
    name         = "api"
    type         = "api"
    port         = 3001
    path_pattern = "apps/api"
    node_version = "22"
    build_command = "pnpm run build"
    start_command = "pnpm run start:prod"
    instance_type = "t3.small"
    health_check = {
      path                = "/api/v1/health"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
      matcher             = "200"
    }
    scaling = {
      min_size                = 1
      max_size                = 5
      desired_capacity        = 2
      scale_up_cpu_threshold  = 70
      scale_down_cpu_threshold = 30
    }
  }
  web = {
    name         = "web"
    type         = "web"
    port         = 3000
    path_pattern = "apps/web"
    node_version = "22"
    build_command = "pnpm run build"
    start_command = "pnpm run start"
    instance_type = "t3.micro"
    health_check = {
      path                = "/api/health"
      interval            = 30
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2
      matcher             = "200"
    }
    scaling = {
      min_size                = 1
      max_size                = 3
      desired_capacity        = 1
      scale_up_cpu_threshold  = 70
      scale_down_cpu_threshold = 30
    }
  }
}
```

### 3. Deploy Infrastructure

```bash
# Plan deployment
terraform plan

# Apply changes
terraform apply

# Confirm with 'yes' when prompted
```

### 4. GitHub App Connection Setup

Before deployment, you need to create a GitHub App connection in AWS CodeStar:

1. **Via AWS Console**:
   - Go to CodePipeline → Settings → Connections
   - Create connection → GitHub
   - Follow the setup wizard to install the GitHub App
   - Copy the connection ARN for your terraform.tfvars

2. **Via AWS CLI**:
```bash
# Create the connection (requires manual GitHub authorization)
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name "github-connection"
```

The connection will automatically trigger pipelines on pushes to the specified branch for files in the application directories.

## Health Check Configuration

Each application now supports comprehensive health check configuration:

- **`path`**: Health check endpoint (e.g., `/api/v1/health`, `/api/health`)
- **`interval`**: Time between health checks in seconds (default: 30)
- **`timeout`**: Health check timeout in seconds (default: 5)
- **`healthy_threshold`**: Consecutive successes before marking healthy (default: 2)
- **`unhealthy_threshold`**: Consecutive failures before marking unhealthy (default: 2)
- **`matcher`**: Expected HTTP response code (default: "200")

## Instance Configuration

Each application can have its own EC2 instance type:

- **`instance_type`**: EC2 instance type per application (e.g., "t3.micro", "t3.small", "t3.medium")
- **Recommendations**:
  - **API applications**: `t3.small` or larger (more CPU/memory for backend processing)
  - **Web applications**: `t3.micro` or `t3.small` (lighter frontend serving)
  - **Production**: Consider `t3.medium` or larger for high-traffic applications

## Auto Scaling Configuration

CPU-based auto scaling is configured per application:

- **`min_size`**: Minimum number of instances (default: 1)
- **`max_size`**: Maximum number of instances (API: 5, Web: 3)
- **`desired_capacity`**: Target number of instances (API: 2, Web: 1)
- **`scale_up_cpu_threshold`**: CPU percentage to scale up (default: 70%)
- **`scale_down_cpu_threshold`**: CPU percentage to scale down (default: 30%)

### Auto Scaling Behavior:
- **Scale Up**: Triggered when average CPU > 70% for 2 consecutive 1-minute periods
- **Scale Down**: Triggered when average CPU < 30% for 2 consecutive 5-minute periods
- **Cooldown**: 5 minutes between scaling actions to prevent thrashing

## Managing Applications

### Adding a New Application

1. Update `applications` variable in `terraform.tfvars`:

```hcl
applications = {
  api = { ... }  # existing
  web = { ... }  # existing
  mobile-api = {
    name              = "mobile-api"
    type              = "api"
    port              = 3002
    path_pattern      = "apps/mobile-api"
    node_version      = "22"
    build_command     = "pnpm run build"
    start_command     = "pnpm run start:prod"
    health_check_path = "/mobile/v1/health"
  }
}
```

2. Apply changes:
```bash
terraform apply
```

### Removing an Application

1. Remove the application from `applications` variable in `terraform.tfvars`
2. Apply changes:
```bash
terraform apply
```

### Updating Application Configuration

1. Modify the application configuration in `terraform.tfvars`
2. Apply changes:
```bash
terraform apply
```

## Monitoring and Troubleshooting

### Check Pipeline Status

```bash
# Get pipeline names
terraform output pipeline_names

# Check pipeline status in AWS Console
aws codepipeline get-pipeline-state --name <pipeline-name>
```

### View Logs

```bash
# CodeBuild logs
aws logs tail /aws/codebuild/<project-name> --follow

# CodeDeploy logs
aws logs tail /aws/codedeploy/<application-name> --follow

# Application logs (on EC2 instances)
sudo pm2 logs <app-name>
```

### Common Issues

1. **Build Failures**: Check CodeBuild logs for compilation errors
2. **Deployment Failures**: Verify appspec.yml and deployment scripts
3. **Health Check Failures**: Ensure application starts correctly and health endpoint responds
4. **Environment Variables**: Verify SSM parameters are set correctly

### Useful Commands

```bash
# Check infrastructure status
terraform show

# Get all outputs
terraform output

# Refresh state
terraform refresh

# View execution plan
terraform plan

# Format configuration files
terraform fmt -recursive
```

## Undeployment

### Remove Specific Application

1. Remove application from `applications` variable in `terraform.tfvars`
2. Apply changes:
```bash
terraform apply
```

### Complete Infrastructure Removal

```bash
# Navigate to environment directory
cd terraform/environments/prod

# Destroy all resources
terraform destroy

# Confirm with 'yes' when prompted
```

**Warning**: This will permanently delete all AWS resources including load balancers, EC2 instances, and data.

### Selective Resource Removal

```bash
# Remove specific resource
terraform destroy -target=module.infrastructure.module.applications["api"]

# Remove multiple resources
terraform destroy \
  -target=module.infrastructure.module.applications["api"] \
  -target=module.infrastructure.module.applications["web"]
```

## State Management

### Remote State (Recommended for Production)

Uncomment and configure the S3 backend in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### State Commands

```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show <resource-address>

# Import existing resource
terraform import <resource-address> <resource-id>

# Remove resource from state
terraform state rm <resource-address>
```

## Security Best Practices

1. **Environment Variables**: Never commit secrets to Git - use AWS SSM Parameter Store
2. **IAM Permissions**: Use least privilege principle for all IAM roles
3. **State Files**: Store Terraform state in encrypted S3 bucket
4. **Access Keys**: Rotate GitHub personal access tokens regularly
5. **EC2 Access**: Use Systems Manager Session Manager instead of SSH when possible

## Cost Optimization

1. **Instance Types**: Use appropriate instance sizes for your workload
2. **Auto Scaling**: Configure proper scaling policies to handle traffic
3. **Resources**: Remove unused applications to reduce costs
4. **Monitoring**: Set up CloudWatch billing alarms

## Support

For issues with:
- **Infrastructure**: Check AWS CloudFormation events and CloudWatch logs
- **CI/CD Pipelines**: Review CodePipeline execution history
- **Applications**: Check PM2 logs and application health endpoints
- **Terraform**: Run `terraform validate` and check syntax