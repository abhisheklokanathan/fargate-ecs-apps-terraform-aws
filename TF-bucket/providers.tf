terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "databucketfortfs3"
    key = "demo/terrafrom.tf.state"
    region = "ap-south-1"
    dynamodb_table = "terraform_state"
    encrypt = true
    
  }
}

# --- Providers ---
provider "aws" {
  region = "us-east-1"
  alias  = "east" # Lambda@Edge must be in us-east-1
}
