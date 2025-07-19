# AWS Infrastructure Requirements for ComptaStar

This document summarizes the AWS infrastructure requirements based on our conversation and design decisions.

## Overview

ComptaStar is a monorepo Node.js application requiring AWS infrastructure for two main applications:
- **API Application** (NestJS) - Backend services
- **Web Application** (Next.js) - Frontend interface

## Core Architecture Requirements

### 1. Load Balancer Strategy
- **One Application Load Balancer per application**
- **One target group per ALB** for normal traffic routing
- Target group naming: `${project_name}-${environment}-${app_name}-tg`
- Health checks configured per application with custom endpoints

### 2. Blue/Green Deployment Strategy
- **CodeDeploy handles blue/green deployments** (NOT the load balancer)
- CodeDeploy deployment group configured with:
  - `COPY_AUTO_SCALING_GROUP` strategy
  - Automatic traffic rerouting through single target group
  - **15-minute termination delay** for original instances
  - Blue/green deployment type with immediate traffic switching

### 3. Auto Scaling Configuration
- **CPU-based Simple Scaling policies**
- Policy names include CPU percentage: `scale-up-70percent`, `scale-down-30percent`
- Configurable thresholds per application:
  - Scale up when CPU > 70% for 2 consecutive 1-minute periods
  - Scale down when CPU < 30% for 2 consecutive 5-minute periods
  - 5-minute cooldown between scaling actions
- Per-application min/max instance configuration

### 4. Health Check System
- **Next.js API route** for web application: `/api/health`
- **NestJS health endpoint** for API application: `/api/v1/health`
- Comprehensive health check configuration:
  - Interval, timeout, thresholds, and response matcher
  - Configurable per application

## Parameter Management

### 1. SSM Parameter Store
- Simplified naming convention: `/{environment}/{app_name}/{parameter_name}`
- **No "comptastar" prefix** - only environment and app name
- Parameter types inferred automatically (String, Integer, URL, etc.)

### 2. Environment Variable Tools
- **Python setup-parameters.py script** with three modes:
  - No args: Dry run showing what would be created
  - `-c`: Interactive creation with type-aware prompts
  - `-cf`: Direct creation using .env.example values
- **env-manager.sh script** for retrieving parameters to create .env files

## CI/CD Pipeline Requirements

### 1. GitHub Integration
- **GitHub App connection** (not OAuth tokens) via AWS CodeStar
- Automatic pipeline triggers on code changes
- Repository and branch selection through AWS UI

### 2. CodePipeline Structure
- Source: GitHub via CodeStar connection
- Build: CodeBuild with Node.js 22 and pnpm
- Deploy: CodeDeploy with blue/green strategy

### 3. CodeBuild Configuration
- Node.js 22 runtime
- pnpm package manager
- Lint, test, and build phases
- Artifact caching for performance

## Instance and Scaling Configuration

### 1. Instance Types
- **Per-application instance type configuration**
- API applications: `t3.small` or larger (backend processing)
- Web applications: `t3.micro` or `t3.small` (frontend serving)

### 2. Scaling Policies
- CPU-based with percentage in policy names
- Configurable per application:
  - Min size, max size, desired capacity
  - Scale up/down CPU thresholds

## Security and Access

### 1. IAM Permissions
- EC2 instances with SSM Parameter Store access
- CodeDeploy with ELB and Auto Scaling permissions
- Least privilege principle for all roles

### 2. Parameter Security
- Environment variables stored in SSM Parameter Store
- No secrets in Git repository
- Secure parameter retrieval during deployment

## Network Architecture

### 1. VPC Configuration
- Public subnets for load balancers
- Private subnets for application instances
- Security groups with appropriate access rules

### 2. Security Groups
- ALB security group: HTTP/HTTPS from internet
- Application security group: App port from ALB only
- SSH access from VPC CIDR for management

## Monitoring and Logging

### 1. CloudWatch Integration
- CPU utilization alarms for auto scaling
- Application logs in CloudWatch log groups
- Deployment failure monitoring

### 2. Health Monitoring
- Application-specific health endpoints
- Target group health checks
- Deployment rollback on failures

## Application-Specific Requirements

### API Application (NestJS)
- Port: 3001
- Health endpoint: `/api/v1/health`
- Path pattern: `/api/*`
- Build command: `pnpm run build`
- Start command: `pnpm run start:prod`

### Web Application (Next.js)
- Port: 3000
- Health endpoint: `/api/health`
- Path pattern: `/*` (catch-all)
- Build command: `pnpm run build`
- Start command: `pnpm run start`

## Deployment Scripts

### Application Lifecycle Hooks
- `install_dependencies.sh`: System dependencies and runtime
- `configure_environment.sh`: Environment variables from SSM
- `start_server.sh`: Application startup with PM2
- `stop_server.sh`: Graceful application shutdown

### Parameter Management
- Dry run validation before deployment
- Interactive parameter creation with examples
- Bulk parameter creation from .env.example files

## Key Design Principles

1. **Blue/Green handled by CodeDeploy**, not load balancer target groups
2. **One target group per application** for normal traffic
3. **CPU percentage in scaling policy names** for clarity
4. **Simplified parameter naming** without project prefix
5. **Per-application configuration** for flexibility
6. **GitHub App integration** for better security
7. **15-minute blue instance termination** for safe deployments
8. **Type-aware parameter management** with Python tooling

This architecture provides scalable, maintainable infrastructure with proper blue/green deployments, auto scaling, and environment management for the ComptaStar monorepo applications.