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
# Run the parameter setup script
./scripts/setup-parameters.sh

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
instance_type = "t3.small"

# Application configuration (optional - defaults provided)
applications = {
  api = {
    name              = "api"
    type              = "api"
    port              = 3001
    path_pattern      = "apps/api"
    node_version      = "22"
    build_command     = "pnpm run build"
    start_command     = "pnpm run start:prod"
    health_check_path = "/api/v1/health"
  }
  web = {
    name              = "web"
    type              = "web"
    port              = 3000
    path_pattern      = "apps/web"
    node_version      = "22"
    build_command     = "pnpm run build"
    start_command     = "pnpm run start"
    health_check_path = "/"
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