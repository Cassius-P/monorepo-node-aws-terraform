# ComptaStar Multi-Application Infrastructure

This directory contains the Terraform infrastructure code for the ComptaStar monorepo, implementing separate CI/CD pipelines with blue-green deployment for multiple applications using AWS services.

## Architecture Overview

### Multi-Application Support
- **API Application**: NestJS backend service
- **Web Application**: Next.js frontend application
- **Independent Pipelines**: Each app has its own CI/CD pipeline
- **Separate Load Balancers**: Each app gets its own ALB for independent scaling
- **Path-Based Triggers**: Pipelines trigger only on changes to their specific app directory

### Infrastructure Components
- **Shared VPC**: Single VPC with public/private subnets across 2 AZs
- **Per-App EC2**: Separate Auto Scaling Groups for each application
- **Per-App ALB**: Independent Application Load Balancers with blue-green targets
- **Per-App Pipeline**: Separate CodePipeline, CodeBuild, and CodeDeploy for each app
- **Shared Systems Manager**: Centralized parameter store for all app configurations
- **CloudWatch**: Comprehensive monitoring and logging per application

### CI/CD Flow (Per Application)
1. **Source**: GitHub webhook triggers on changes to specific app directory (`apps/api/` or `apps/web/`)
2. **Build**: CodeBuild compiles app using app-specific buildspec.yml
3. **Deploy**: CodeDeploy performs blue-green deployment to app-specific EC2 instances
4. **Monitor**: CloudWatch tracks deployment health and application metrics per app

## Prerequisites

### 1. AWS CLI and Terraform
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 2. AWS Resources Setup

#### Create GitHub Token Secret
```bash
# Create a GitHub personal access token with repo permissions
aws secretsmanager create-secret \
    --name "github-token" \
    --description "GitHub token for CodePipeline" \
    --secret-string '{"token":"your-github-token","webhook_secret":"your-webhook-secret"}'
```

#### Create EC2 Key Pair
```bash
# Create a key pair for EC2 instances
aws ec2 create-key-pair \
    --key-name comptastar-prod-key \
    --query 'KeyMaterial' \
    --output text > comptastar-prod-key.pem

chmod 400 comptastar-prod-key.pem
```

### 3. Environment Variables Setup for All Applications
**IMPORTANT**: All environment variables are managed exclusively via AWS Systems Manager Parameter Store. Terraform does not create or manage any parameter values.

```bash
# Set up API parameters (required before deployment)
./scripts/setup-parameters.sh -a api -e prod -v -c

# Set up Web parameters (required before deployment)
./scripts/setup-parameters.sh -a web -e prod -v -c
```

## Application Configuration

### Application Structure
Each application is defined in the `applications` variable with the following structure:

```hcl
applications = {
  api = {
    name              = "api"
    type              = "api"           # "api" or "web"
    port              = 3001
    path_pattern      = "apps/api"     # Directory pattern for triggers
    node_version      = "22"
    build_command     = "pnpm run build"
    start_command     = "pnpm run start:prod"
    health_check_path = "/api/v1/health"
    # Note: Environment variables are managed via AWS Systems Manager
  }
  web = {
    name              = "web"
    type              = "web"
    port              = 3000
    path_pattern      = "apps/web"     # Directory pattern for triggers
    node_version      = "22"
    build_command     = "pnpm run build"
    start_command     = "pnpm run start"
    health_check_path = "/"
    # Note: Environment variables are managed via AWS Systems Manager
  }
}
```

### Adding New Applications
1. **Create Application Directory**: `apps/new-app/`
2. **Add Configuration Files**:
   - `.env.example` (defines required environment variables)
   - `buildspec.yml`
   - `appspec.yml` 
   - `scripts/` directory with deployment scripts
3. **Create Environment Variables**: `./scripts/setup-parameters.sh -a new-app -e prod -v -c`
4. **Update terraform.tfvars**: Add new application configuration (without environment variables)
5. **Deploy Infrastructure**: `terraform apply`

## Deployment

### 1. Production Environment

**Prerequisites**: Ensure all environment variables are created in AWS Systems Manager before deploying infrastructure.

```bash
# 1. Create environment variables first
./scripts/setup-parameters.sh -a api -e prod -v -c
./scripts/setup-parameters.sh -a web -e prod -v -c

# 2. Deploy infrastructure
cd terraform/environments/prod

# Update terraform.tfvars with your values (repository URL, key pair, etc.)
vim terraform.tfvars

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### 2. Configure GitHub Webhooks
After deployment, configure separate webhooks for each application:

```bash
# Get webhook URLs
terraform output webhook_urls
```

For each application:
1. Go to GitHub repository → Settings → Webhooks
2. Add the application-specific webhook URL
3. Set content type to `application/json`
4. Use the webhook secret from AWS Secrets Manager
5. Configure to trigger on push events

## Per-Application Resources

### API Application
- **Load Balancer**: `comptastar-prod-api-alb`
- **Target Groups**: `comptastar-prod-api-blue`, `comptastar-prod-api-green`
- **Auto Scaling Group**: `comptastar-prod-api-asg`
- **Pipeline**: `comptastar-prod-api-pipeline`
- **Build Project**: `comptastar-prod-api-build`
- **Deploy Application**: `comptastar-prod-api-app`

### Web Application
- **Load Balancer**: `comptastar-prod-web-alb`
- **Target Groups**: `comptastar-prod-web-blue`, `comptastar-prod-web-green`
- **Auto Scaling Group**: `comptastar-prod-web-asg`
- **Pipeline**: `comptastar-prod-web-pipeline`
- **Build Project**: `comptastar-prod-web-build`
- **Deploy Application**: `comptastar-prod-web-app`

## Environment Variables Management

**CRITICAL**: All environment variables are managed exclusively through AWS Systems Manager Parameter Store. Terraform does not create, manage, or contain any environment variable values.

### Per-Application Parameters
Parameters are stored with the pattern: `/comptastar/{environment}/{app_name}/{parameter_name}`

Examples:
- `/comptastar/prod/api/NEST_PORT`
- `/comptastar/prod/web/NEXT_PORT`
- `/comptastar/prod/web/API_URL`
- `/comptastar/prod/web/NEXT_PUBLIC_APP_NAME`

### Managing Parameters

#### For API Application
```bash
# View current parameters
./scripts/env-manager.sh -a api -e prod -v

# Create/update parameters
./scripts/setup-parameters.sh -a api -e prod -v -c
```

#### For Web Application
```bash
# View current parameters
./scripts/env-manager.sh -a web -e prod -v

# Create/update parameters
./scripts/setup-parameters.sh -a web -e prod -v -c
```

### Adding Parameters
1. **Update .env.example**: Add new variable to `apps/{app}/.env.example`
2. **Create SSM Parameter manually**:
   ```bash
   aws ssm put-parameter \
     --name "/comptastar/prod/{app}/NEW_VARIABLE" \
     --value "your-value" \
     --type String
   ```
3. **Or use helper script** (recommended):
   ```bash
   ./scripts/setup-parameters.sh -a {app} -e prod -v -c
   ```

### Parameter Management Workflow
1. **All parameters must be created manually** in AWS Systems Manager before deployment
2. **Terraform does not manage parameter values** - it only references them
3. **Use .env.example files** as the source of truth for required parameters
4. **Use setup scripts** to streamline parameter creation process

## Monitoring and Logging

### Application-Specific CloudWatch Logs
- **API Application**: `/aws/ec2/comptastar/prod/api`
- **Web Application**: `/aws/ec2/comptastar/prod/web`
- **API CodeBuild**: `/aws/codebuild/comptastar/prod/api`
- **Web CodeBuild**: `/aws/codebuild/comptastar/prod/web`
- **API CodeDeploy**: `/aws/codedeploy/comptastar/prod/api`
- **Web CodeDeploy**: `/aws/codedeploy/comptastar/prod/web`
- **API Pipeline**: `/aws/codepipeline/comptastar/prod/api`
- **Web Pipeline**: `/aws/codepipeline/comptastar/prod/web`

### Accessing Logs
```bash
# View API application logs
aws logs tail /aws/ec2/comptastar/prod/api --follow

# View Web application logs  
aws logs tail /aws/ec2/comptastar/prod/web --follow

# View specific pipeline logs
aws logs tail /aws/codepipeline/comptastar/prod/api --follow
```

### Application URLs
After deployment:
```bash
# Get all load balancer DNS names
terraform output load_balancer_dns

# Access applications
curl http://{api-alb-dns}/api/v1/health
curl http://{web-alb-dns}/
```

## Troubleshooting

### Pipeline Issues

#### Check Pipeline Status
```bash
# API pipeline
aws codepipeline get-pipeline-state --name comptastar-prod-api-pipeline

# Web pipeline
aws codepipeline get-pipeline-state --name comptastar-prod-web-pipeline
```

#### Pipeline Not Triggering
1. **Check Webhook Configuration**: Ensure path pattern matches directory changes
2. **Verify Webhook URL**: Each app needs its own webhook
3. **Check GitHub Events**: Verify push events are configured
4. **Path Pattern**: API triggers on `apps/api/*`, Web triggers on `apps/web/*`

### Application-Specific Issues

#### API Application
```bash
# Check API health
curl http://{api-alb-dns}/api/v1/health

# View API logs
aws logs tail /aws/ec2/comptastar/prod/api --follow

# SSH to API instance
ssh -i comptastar-prod-key.pem ec2-user@{api-instance-ip}
pm2 status comptastar-api
```

#### Web Application
```bash
# Check Web health
curl http://{web-alb-dns}/

# View Web logs
aws logs tail /aws/ec2/comptastar/prod/web --follow

# SSH to Web instance
ssh -i comptastar-prod-key.pem ec2-user@{web-instance-ip}
pm2 status comptastar-web
```

### Cross-Application Communication
If the web app needs to communicate with the API:

1. **Internal Communication**: Use internal ALB DNS names
2. **Service Discovery**: Consider AWS Service Discovery for dynamic discovery
3. **Environment Variables**: Set API_URL to point to API load balancer

## Security Considerations

### Network Isolation
- Each application has its own security groups
- Applications can communicate through load balancers
- Private subnets isolate application instances

### IAM Separation
- Each application has separate IAM roles
- SSM parameters are scoped per application
- CodeDeploy roles are application-specific

### Parameter Store Security
- Application-specific parameter paths
- Sensitive values use SecureString type
- KMS encryption for secure parameters

## Scaling and Performance

### Independent Scaling
- Each application scales independently
- Separate Auto Scaling Groups per app
- Different instance types possible per application

### Cost Optimization
- Resource tagging by application
- Independent cost tracking per app
- Ability to shut down specific applications

## Next Steps

### Infrastructure Enhancements
1. **Database Integration**: Add RDS with per-app databases
2. **CDN Setup**: CloudFront for web application static assets
3. **Custom Domains**: Route53 with per-app subdomains
4. **SSL/TLS**: ACM certificates for HTTPS
5. **Service Mesh**: AWS App Mesh for inter-service communication

### Operational Improvements
1. **Monitoring Dashboards**: Per-application CloudWatch dashboards
2. **Alerting**: Application-specific CloudWatch alarms
3. **Log Aggregation**: Centralized logging with ElasticSearch
4. **Performance Testing**: Load testing per application
5. **Backup Strategy**: Application-specific backup policies

### Development Workflow
1. **Feature Branches**: Branch-specific deployments
2. **Integration Testing**: Cross-application test suites
3. **Staging Environment**: Multi-app staging setup
4. **Canary Deployments**: Gradual traffic shifting per app