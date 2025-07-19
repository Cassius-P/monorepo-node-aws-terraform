variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_groups" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "applications" {
  description = "Map of applications configuration"
  type = map(object({
    name         = string
    type         = string
    port         = number
    path_pattern = string
    node_version = string
    build_command = string
    start_command = string
    instance_type = string
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
  }))
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}