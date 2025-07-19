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

variable "target_group_blue_name" {
  description = "Name of the blue target group"
  type        = string
}

variable "target_group_green_name" {
  description = "Name of the green target group"
  type        = string
}

variable "load_balancer_listener_arn" {
  description = "ARN of the load balancer listener"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}