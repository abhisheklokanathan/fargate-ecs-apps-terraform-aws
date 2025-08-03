output "ecs_cluster_name" {
  value = aws_ecs_cluster.production-fargate-cluster.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.production-fargate-cluster.arn
}


output "ecs_alb_listener_arn" {
  value = aws_alb_listener.ecs_alb_https_listener.arn   # Replace 'ecs_listener' with your ALB listener resource name
}

output "ecs_domain_name" {
  value = aws_route53_record.studysite.name  # Replace with your Route53 domain record or variable as appropriate
}
