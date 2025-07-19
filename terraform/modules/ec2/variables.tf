variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type (deprecated - use app_config.instance_type)"
  type        = string
  default     = null
}

variable "key_pair_name" {
  description = "AWS Key Pair name"
  type        = string
}

# These are now passed from app_config.scaling - keeping for backward compatibility
variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group (deprecated - use app_config.scaling)"
  type        = number
  default     = null
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group (deprecated - use app_config.scaling)"
  type        = number
  default     = null
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group (deprecated - use app_config.scaling)"
  type        = number
  default     = null
}

variable "target_group_arns" {
  description = "List of target group ARNs"
  type        = list(string)
  default     = []
}

variable "app_config" {
  description = "Application configuration"
  type = object({
    name         = string
    type         = string
    port         = number
    path_pattern = string
    node_version = string
    build_command = string
    start_command = string
    instance_type = string # EC2 instance type per application
    health_check = object({
      path                = string
      interval            = number
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
      matcher             = string
    })
    scaling = object({
      min_size                = number
      max_size                = number
      desired_capacity        = number
      scale_up_cpu_threshold  = number
      scale_down_cpu_threshold = number
    })
  })
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}