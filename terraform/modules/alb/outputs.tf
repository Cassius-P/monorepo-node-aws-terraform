output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arns" {
  description = "Map of application target group ARNs"
  value       = { for k, v in aws_lb_target_group.app : k => v.arn }
}

output "target_group_names" {
  description = "Map of application target group names"
  value       = { for k, v in aws_lb_target_group.app : k => v.name }
}

output "listener_arn" {
  description = "ARN of the ALB listener"
  value       = aws_lb_listener.http.arn
}