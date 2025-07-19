# S3 Bucket for Pipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-${var.environment}-${var.app_name}-pipeline-artifacts-${random_id.pipeline_bucket_suffix.hex}"

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "pipeline_bucket_suffix" {
  byte_length = 4
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for CodePipeline
resource "aws_iam_policy" "codepipeline_policy" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-codepipeline-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = var.github_connection_arn
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

# Parse GitHub repository information
locals {
  # Extract owner and repo from GitHub URL
  github_parts = split("/", replace(var.source_repository_url, "https://github.com/", ""))
  github_owner = local.github_parts[0]
  github_repo  = local.github_parts[1]
}

# CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-${var.environment}-${var.app_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = "${local.github_owner}/${local.github_repo}"
        BranchName       = var.default_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = var.codedeploy_application_name
        DeploymentGroupName = var.codedeploy_group_name
      }
    }
  }

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# EventBridge Rule for triggering pipeline on push to specified branch
resource "aws_cloudwatch_event_rule" "github_push" {
  name        = "${var.project_name}-${var.environment}-${var.app_name}-github-push"
  description = "Trigger ${var.app_name} pipeline on GitHub push"

  event_pattern = jsonencode({
    source      = ["aws.codecommit", "aws.s3"]
    detail-type = ["CodeCommit Repository State Change", "Object Created"]
    detail = {
      referenceName = [var.default_branch]
    }
  })

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# EventBridge Target to trigger pipeline
resource "aws_cloudwatch_event_target" "pipeline_trigger" {
  rule      = aws_cloudwatch_event_rule.github_push.name
  target_id = "TriggerPipeline"
  arn       = aws_codepipeline.pipeline.arn

  role_arn = aws_iam_role.eventbridge_role.arn
}

# IAM Role for EventBridge to trigger CodePipeline
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for EventBridge to trigger CodePipeline
resource "aws_iam_policy" "eventbridge_policy" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-eventbridge-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codepipeline:StartPipelineExecution"
        ]
        Resource = aws_codepipeline.pipeline.arn
      }
    ]
  })

  tags = var.tags
}

# Attach EventBridge policy to role
resource "aws_iam_role_policy_attachment" "eventbridge_policy_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_policy.arn
}

# CloudWatch Log Group for CodePipeline
resource "aws_cloudwatch_log_group" "codepipeline" {
  name              = "/aws/codepipeline/${var.project_name}/${var.environment}/${var.app_name}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# EventBridge Rule for Pipeline State Changes
resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  name        = "${var.project_name}-${var.environment}-${var.app_name}-pipeline-state-change"
  description = "Capture ${var.app_name} pipeline state changes"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.pipeline.name]
    }
  })

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# SNS Topic for Pipeline Notifications
resource "aws_sns_topic" "pipeline_notifications" {
  name = "${var.project_name}-${var.environment}-${var.app_name}-pipeline-notifications"

  tags = merge(var.tags, {
    Application = var.app_name
  })
}

# EventBridge Target to SNS
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.pipeline_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn
}