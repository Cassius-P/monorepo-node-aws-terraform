# Application-specific infrastructure module
# This module creates all resources needed for a single application (API or Web)

locals {
  app_name = var.app_config.name
  app_port = var.app_config.port
  app_type = var.app_config.type # "api" or "web"
  
  # Health check configuration from app config
  health_check = var.app_config.health_check
  
  # Scaling configuration from app config
  scaling = var.app_config.scaling
  
  # Build environment varies by app type
  build_image = var.app_config.type == "api" ? "aws/codebuild/amazonlinux2-x86_64-standard:5.0" : "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.project_name}-${var.environment}-${local.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${local.app_name}-alb"
    Application = local.app_name
  })
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-${local.app_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for ${local.app_name} Application Load Balancer"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${local.app_name}-alb-sg"
    Application = local.app_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Application Servers
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-${local.app_name}-app-"
  vpc_id      = var.vpc_id
  description = "Security group for ${local.app_name} application servers"

  ingress {
    description     = "HTTP from ALB"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${local.app_name}-app-sg"
    Application = local.app_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for Application Load Balancer
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-${local.app_name}-tg"
  port     = local.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = local.health_check.healthy_threshold
    unhealthy_threshold = local.health_check.unhealthy_threshold
    timeout             = local.health_check.timeout
    interval            = local.health_check.interval
    path                = local.health_check.path
    matcher             = local.health_check.matcher
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${local.app_name}-tg"
    Application = local.app_name
  })
}

# Self-signed SSL certificate for HTTPS (when no ACM certificate is provided)
resource "tls_private_key" "alb_private_key" {
  count     = var.enable_https && var.ssl_certificate_arn == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  count           = var.enable_https && var.ssl_certificate_arn == "" ? 1 : 0
  private_key_pem = tls_private_key.alb_private_key[0].private_key_pem

  subject {
    common_name  = "*.${var.project_name}-${var.environment}.local"
    organization = "ComptaStar"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb_cert" {
  count            = var.enable_https && var.ssl_certificate_arn == "" ? 1 : 0
  private_key      = tls_private_key.alb_private_key[0].private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert[0].cert_pem

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${local.app_name}-cert"
    Application = local.app_name
  })
}

# ALB Listener - HTTP (always forward to target group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Application = local.app_name
  })
}

# ALB Listener - HTTPS (always forward to target group when enabled)
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : aws_acm_certificate.alb_cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Application = local.app_name
  })
}

# ALB Listener Rule for application traffic (HTTP)
resource "aws_lb_listener_rule" "app_http" {
  count        = var.enable_https ? 0 : 1
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = var.app_config.type == "api" ? ["/api/*"] : ["/*"]
    }
  }

  tags = merge(var.tags, {
    Application = local.app_name
  })
}

# ALB Listener Rule for application traffic (HTTPS)
resource "aws_lb_listener_rule" "app_https" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = var.app_config.type == "api" ? ["/api/*"] : ["/*"]
    }
  }

  tags = merge(var.tags, {
    Application = local.app_name
  })
}

# EC2 Module for this application
module "ec2" {
  source = "../ec2"

  project_name     = var.project_name
  environment      = var.environment
  app_name         = local.app_name
  aws_region       = var.aws_region
  vpc_id           = var.vpc_id
  private_subnets  = var.private_subnets
  security_groups  = [aws_security_group.app.id]
  key_pair_name    = var.key_pair_name
  target_group_arns = [aws_lb_target_group.app.arn]
  app_config       = var.app_config
  tags             = var.tags
}

# CodeBuild Module for this application
module "codebuild" {
  source = "../codebuild"

  project_name          = var.project_name
  environment           = var.environment
  app_name              = local.app_name
  source_repository_url = var.source_repository_url
  app_config           = var.app_config
  tags                 = var.tags
}

# CodeDeploy Module for this application
module "codedeploy" {
  source = "../codedeploy"

  project_name                = var.project_name
  environment                 = var.environment
  app_name                    = local.app_name
  auto_scaling_group_name     = module.ec2.auto_scaling_group_name
  target_group_name           = aws_lb_target_group.app.name
  tags                        = var.tags
}

# CodePipeline Module for this application
module "codepipeline" {
  source = "../codepipeline"

  project_name                = var.project_name
  environment                 = var.environment
  app_name                    = local.app_name
  source_repository_url       = var.source_repository_url
  github_connection_arn       = var.github_connection_arn
  default_branch              = var.default_branch
  codebuild_project_name      = module.codebuild.project_name
  codedeploy_application_name = module.codedeploy.application_name
  codedeploy_group_name       = module.codedeploy.deployment_group_name
  app_config                  = var.app_config
  tags                        = var.tags
}