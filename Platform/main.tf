data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    region = "${var.region}"
    bucket = "${var.remote_state_bucket}"
    key    =  "${var.remote_state_key}"
  }
}

resource "aws_ecs_cluster" "production-fargate-cluster" {
    name = "Production-Fargate-Cluster" 
}

resource "aws_alb" "ecs_cluster_alb" {
  name = "${var.ecs_cluster_name}-ALB"
  internal = false
  security_groups = ["${aws_security_group.ecs_alb_security_group.id}"]
  subnets = [
  data.terraform_remote_state.infrastructure.outputs.public_1_subnet_cidr,
  data.terraform_remote_state.infrastructure.outputs.public_2_subnet_cidr,
  data.terraform_remote_state.infrastructure.outputs.public_3_subnet_cidr,
]

  tags = {
    Name = "${var.ecs_cluster_name}-ALB"
  }
}

resource "aws_security_group" "ecs_security_group" {
  name        = "${var.ecs_cluster_name}-SG"
  description = "Security group for ECS to communicate in and out"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id

  ingress {
    from_port   = 32768
    protocol    = "TCP"
    to_port     = 65535
    cidr_blocks = [data.terraform_remote_state.infrastructure.outputs.vpc_cidr_block]
  }

  ingress {
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
    cidr_blocks = var.internet_cidr_blocks
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = var.internet_cidr_blocks
  }

  tags = {
    Name = "${var.ecs_cluster_name}-SG"
  }
}

resource "aws_security_group" "ecs_alb_security_group" {
  name = "${var.ecs_cluster_name}-ALB-SG"
  description = "Security Group for ALB to traffic for ECS cluster"
  vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id
  ingress {
    from_port = 443
    protocol  = "TCP"
    to_port   = 443
    cidr_blocks = var.internet_cidr_blocks
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = var.internet_cidr_blocks
  }
}

#resource "aws_route53_zone" "public_zone" {
#  name = var.aws_route53_zone
  
#}

#resource "aws_acm_certificate" "studysite_cert" {
#  domain_name       = "*.${var.ecs_domain_name}"
#  validation_method = "DNS"
#  subject_alternative_names = ["studysite.shop"]

#  tags = {
#    Name = "${var.ecs_cluster_name}-Certificate"
#  }

  # lifecycle {
  #   create_before_destroy = true
  # }
#}

#data "aws_route53_zone" "domain_zone" {
#  name = "studysite.shop"
#  depends_on = [ aws_route53_zone.public_zone ]
#}

#resource "aws_route53_record" "studysite_validation" {
#  for_each = {
#    for dvo in aws_acm_certificate.studysite_cert.domain_validation_options : dvo.domain_name
#    =>{
#       name = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type = dvo.resource_record_type
#    }

#  }
#  name = each.value.name
#  records = [each.value.record]
#  ttl = 60
#  type = each.value.type
#  zone_id = data.aws_route53_zone.domain_zone.zone_id
#  allow_overwrite = true
#}

#resource "aws_acm_certificate_validation" "studysite_validation" {
#  provider = aws.south
#  certificate_arn = aws_acm_certificate.studysite_cert.arn
#  validation_record_fqdns = [for record in aws_route53_record.studysite_validation : record.fqdn ]
#  depends_on = [ aws_route53_record.studysite_validation ]
  
#}

#resource "aws_route53_record" "studysite" {
#  zone_id = data.aws_route53_zone.domain_zone.zone_id
#  name    = "*.${var.ecs_domain_name}"
#  type    = "A"

#  alias {
#    name                   = aws_alb.ecs_cluster_alb.dns_name
#    zone_id                = aws_alb.ecs_cluster_alb.zone_id
#    evaluate_target_health = false
#  }
#}

#resource "aws_route53_record" "studysite_www" {
#  zone_id = data.aws_route53_zone.domain_zone.zone_id
#  name    = "${var.ecs_domain_name}"
#  type    = "A"

#  alias {
#    name                   = aws_alb.ecs_cluster_alb.dns_name
#    zone_id                = aws_alb.ecs_cluster_alb.zone_id
#    evaluate_target_health = false
#  }
#}

resource "aws_alb_listener" "ecs_alb_https_listener" {
  load_balancer_arn = aws_alb.ecs_cluster_alb.arn
  port              = 80
  protocol          = "HTTP"
  #ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  #certificate_arn   = aws_acm_certificate.studysite_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_app_target_group.arn
  }
  #depends_on = [ aws_acm_certificate_validation.studysite_validation, aws_alb_target_group.ecs_default_target_group ]
  # depends_on = [ aws_alb_target_group.ecs_default_target_group ]
}

resource "aws_alb_target_group" "ecs_app_target_group" {
  name        = "${var.ecs_service_name}-TG"
  port        = var.docker_container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = "60"
    timeout             = "30"
    unhealthy_threshold = "3"
    healthy_threshold   = "3"
  }

  tags = {
    Name = "${var.ecs_cluster_name}-TG"
  }
}

#resource "aws_alb_target_group" "ecs_default_target_group" {
  #  name = "${var.ecs_cluster_name}-TG"
 #  port = 80
 #  protocol = "HTTP"
 #  vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id

#    tags = {
#     Name = "${var.ecs_cluster_name}-TG"
#    }
#    #depends_on = [ aws_route53_record.studysite_validation ]
#}

resource "aws_iam_role" "ecs_cluster_role" {
        name = "${var.ecs_cluster_name}-IAM-ROLE"
        assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
   {
     "Effect": "Allow",
     "Principal": {
        "Service": ["ecs.amazonaws.com", "ec2.amazonaws.com", "application-autoscaling.amazonaws.com"]

     },
      "Action": "sts:AssumeRole"
   }
]
}
EOF        
}



resource "aws_iam_role_policy" "ecs_cluster_policy" {
  name = "${var.ecs_cluster_name}-IAM-Policy"
  role = aws_iam_role.ecs_cluster_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "ecr:*",
          "dynamodb:*",
          "cloudwatch:*",
          "s3:*",
          "rds:*",
          "sqs:*",
          "sns:*",
          "logs:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })
}
