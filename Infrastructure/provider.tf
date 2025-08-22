terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "databucketfortfs3"
    key    = "PROD/terraform.tf.state"
    region = "us-east-1"
    dynamodb_table = "terraform_state"
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  alias = "south"
  region = "us-east-1"
}
