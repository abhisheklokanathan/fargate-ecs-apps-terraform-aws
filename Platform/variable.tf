variable "region" {
  default = "ap-south-1"
}

variable "remote_state_bucket" {
    default = "databucketfortfecs"
}
variable "remote_state_key" {
    default = "PROD/terraform.tf.state"
}
variable "ecs_cluster_name" {
    default = "prod-1-demo"
}
variable "internet_cidr_blocks" {
    default = ["0.0.0.0/0"]
}

variable "aws_route53_zone" {
    type = string
    default = "studysite.shop"
}

variable "ecs_domain_name" {
    type = string
    default = "studysite.shop"
}
