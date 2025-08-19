variable "s3_bucket_name" {
  default = "aws-mypersonal-website-tf"
}

variable "versioned_lambda_name" {
  default = "versionedUriRewriter-tf"
}

variable "update_lambda_name" {
  default = "updateLambdaEdgeVersion-tf"
}

variable "lambda_runtime" {
  default = "python3.9"
}

variable "lambda_handler" {
  default = "lambda_function.lambda_handler"
}