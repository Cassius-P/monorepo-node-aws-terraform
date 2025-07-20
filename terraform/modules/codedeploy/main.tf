# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach AWS managed policy for CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Custom policy for EC2 and PassRole permissions
resource "aws_iam_policy" "codedeploy_custom_policy" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-codedeploy-custom-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "VisualEditor0"
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "ec2:CreateTags",
          "ec2:RunInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach custom policy to role
resource "aws_iam_role_policy_attachment" "codedeploy_custom_policy_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = aws_iam_policy.codedeploy_custom_policy.arn
}

# CodeDeploy Application
resource "aws_codedeploy_app" "app" {
  name             = "${var.project_name}-${var.environment}-${var.app_name}-app"
  compute_platform = "Server"

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "app" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.project_name}-${var.environment}-${var.app_name}-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  # Deployment Style - Blue/Green (not in-place)
  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  # Blue/Green Deployment Configuration
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                         = "TERMINATE"
      termination_wait_time_in_minutes = 15
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  # Auto Scaling Groups
  autoscaling_groups = [var.auto_scaling_group_name]

  # Load Balancer Configuration
  load_balancer_info {
    target_group_info {
      name = var.target_group_name
    }
  }

  # Deployment Configuration for EC2/On-Premise Blue/Green
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  # Auto Rollback Configuration
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  # Alarm Configuration for Auto Rollback
  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.deployment_failure.alarm_name]
  }

  tags = var.tags
}

# CloudWatch Alarm for Deployment Monitoring
resource "aws_cloudwatch_metric_alarm" "deployment_failure" {
  alarm_name          = "${var.project_name}-${var.environment}-${var.app_name}-deployment-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts in ${var.app_name} target group"
  alarm_actions       = []

  dimensions = {
    TargetGroup = var.target_group_name
  }

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# SNS Topic for Deployment Notifications (Optional)
resource "aws_sns_topic" "deployment_notifications" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-deployment-notifications"

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# CloudWatch Log Group for CodeDeploy
resource "aws_cloudwatch_log_group" "codedeploy" {
  name              = "/aws/codedeploy/${var.project_name}/${var.environment}/${var.app_name}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Application = var.app_name
  })
}