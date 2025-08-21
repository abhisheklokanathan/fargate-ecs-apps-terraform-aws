terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "databucketfortfecs"
    key    = "PROD/terraform.tf.state"
    region = "ap-east-1"
    dynamodb_table = "terraform_state_ecs_prod"
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  alias = "south"
  region = "ap-east-1"
}
