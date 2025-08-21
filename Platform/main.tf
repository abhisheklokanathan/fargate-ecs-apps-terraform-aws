data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    key     = PROD/terraform.tf.state
    bucket  = databucketfortfecs
    region  = us-east-1
  }
}

data "terraform_remote_state" "platform_demo" {
  backend = "s3"

  config = {
    key     = demo/terraform.tf.state
    bucket  = databucketfortfecs
    region  = us-east-1
  }
}
resource "aws_ecs_cluster" "production_fargate_cluster" {
  name = "Production-Fargate-Cluster"
}

resource "aws_alb" "ecs_cluster_alb" {
  name            = "${var.ecs_cluster_name}-ALB"
  internal        = false
  security_groups = [aws_security_group.ecs_alb_security_group.id]
  subnets = [
    data.terraform_remote_state.infrastructure.outputs.public_1_subnet_id,
    data.terraform_remote_state.infrastructure.outputs.public_2_subnet_id,
    data.terraform_remote_state.infrastructure.outputs.public_3_subnet_id,
  ]

  tags = {
    Name = "${var.ecs_cluster_name}-ALB"
  }
}

resource "aws_security_group" "ecs_security_group" {
  name        = "${var.ecs_cluster_name}-SG"
  description = "Security group for ECS tasks"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id

  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "TCP"
    cidr_blocks = [data.terraform_remote_state.infrastructure.outputs.vpc_cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.internet_cidr_blocks
  }

  ingress {
    from_port       = var.docker_container_port
    to_port         = var.docker_container_port
    protocol        = "TCP"
    security_groups = [aws_security_group.ecs_alb_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ecs_cluster_name}-SG"
  }
}

resource "aws_security_group" "ecs_alb_security_group" {
  name        = "${var.ecs_cluster_name}-ALB-SG"
  description = "Security Group for ALB"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = var.internet_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = var.internet_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.ecs_cluster_name}-ALB-SG"
  }
}

resource "aws_alb_listener" "ecs_alb_http_listener" {
  load_balancer_arn = aws_alb.ecs_cluster_alb.arn
  port              = 80
  protocol          = "HTTP"
  # ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01" # uncomment if needed
  # certificate_arn = aws_acm_certificate.studysite_cert.arn # uncomment if using HTTPS

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_app_target_group.arn
  }
}

resource "aws_alb_target_group" "ecs_app_target_group" {
  name        = "${var.ecs_cluster_name}-TG"
  port        = var.docker_container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 60
    timeout             = 30
    unhealthy_threshold = 3
    healthy_threshold   = 3
  }

  tags = {
    Name = "${var.ecs_cluster_name}-TG"
  }
}

resource "aws_iam_role" "fargate_iam_role" {
  name = "${var.ecs_cluster_name}-fargate-iam-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_cluster_policy" {
  name = "${var.ecs_cluster_name}-IAM-Policy"
  role = aws_iam_role.fargate_iam_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
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
        ],
        Resource = "*"
      }
    ]
  })
}
