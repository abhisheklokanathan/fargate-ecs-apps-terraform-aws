#data "aws_acm_certificate" "static_site_cert" {
#  domain   = "*.studysite.shop"
#  types    = ["AMAZON_ISSUED"]
#  statuses = ["ISSUED"]
#  most_recent = true
#  provider = aws.east # Make sure this is your us-east-1 provider
#}

#data "aws_route53_zone" "main" {
#  name = "studysite.shop"
#}


data "aws_caller_identity" "current" {}

# IAM Role for Lambdas
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy to allow S3 read access
resource "aws_iam_policy" "lambda_s3_read" {
  name = "LambdaS3ReadAccess"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}/root.json"
        ]
      }
    ]
  })
}

# IAM Policy for Lambda to update/publish another Lambda
resource "aws_iam_policy" "lambda_update_permission" {
  name = "LambdaUpdatePermission"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:PublishVersion"
        ],
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:${var.versioned_lambda_name}"
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_policy_attachment" "lambda_update_policy_attach" {
  name       = "LambdaUpdatePolicyAttach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_update_permission.arn
}

resource "aws_iam_policy_attachment" "lambda_s3_read_attach" {
  name       = "LambdaS3ReadAccessAttach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_s3_read.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket   = var.s3_bucket_name
  provider = aws.east
}

# Lambda function (Lambda@Edge)
resource "aws_lambda_function" "versioned_uri_rewriter" {
  provider         = aws.east
  function_name    = var.versioned_lambda_name
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda_handler
  filename         = "versionedUriRewriter.zip"
  source_code_hash = filebase64sha256("versionedUriRewriter.zip")
  publish          = true
}

# Lambda function triggered by S3
resource "aws_lambda_function" "update_lambda_edge_version" {
  function_name    = var.update_lambda_name
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda_handler
  filename         = "updateLambdaEdgeVersion.zip"
  source_code_hash = filebase64sha256("updateLambdaEdgeVersion.zip")
}

# Permission to allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_lambda_edge_version.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# S3 triggers Lambda on new object
resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.update_lambda_edge_version.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Origin Access Control for CloudFront
