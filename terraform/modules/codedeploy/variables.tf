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

variable "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "target_group_name" {
  description = "Name of the target group for load balancer"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}