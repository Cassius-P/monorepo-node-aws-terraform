# Data source for the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for accessing SSM parameters
resource "aws_iam_policy" "ssm_policy" {
  name        = "${var.project_name}-${var.environment}-${var.app_name}-ssm-policy"
  description = "Policy for accessing SSM parameters for ${var.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.environment}/${var.app_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.*.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

# Attach AWS managed policy for SSM agent
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for CloudWatch agent
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = var.tags
}

# User Data Script
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
    app_name     = var.app_name
  }))
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-${var.app_name}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = var.security_groups

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = local.user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name        = "${var.project_name}-${var.environment}-${var.app_name}-app"
      Application = var.app_name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name        = "${var.project_name}-${var.environment}-${var.app_name}-app-volume"
      Application = var.app_name
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-${var.app_name}-asg"
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = var.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Enable instance refresh for blue-green deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-${var.app_name}-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Application"
    value               = var.app_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.project_name}/${var.environment}/${var.app_name}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Application = var.app_name
  })
}