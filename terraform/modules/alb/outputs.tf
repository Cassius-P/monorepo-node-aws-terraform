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

output "target_group_blue_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "ARN of the green target group"
  value       = aws_lb_target_group.green.arn
}

output "target_group_blue_name" {
  description = "Name of the blue target group"
  value       = aws_lb_target_group.blue.name
}

output "target_group_green_name" {
  description = "Name of the green target group"
  value       = aws_lb_target_group.green.name
}

output "listener_arn" {
  description = "ARN of the ALB listener"
  value       = aws_lb_listener.http.arn
}