data "aws_acm_certificate" "static_site_cert" {
  domain   = "*.studysite.shop"
  types    = ["AMAZON_ISSUED"]
  statuses = ["ISSUED"]
  most_recent = true
  provider = aws.east # Make sure this is your us-east-1 provider
}

data "aws_route53_zone" "main" {
  name = "studysite.shop"
}


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
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "default-oac"
  description                       = "OAC for CloudFront to access S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for static.studysite.shop"

  aliases = ["s3.studysite.shop"]

  origin {
    domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.bucket.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.bucket.bucket}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.versioned_uri_rewriter.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
     acm_certificate_arn      = data.aws_acm_certificate.static_site_cert.arn
     ssl_support_method       = "sni-only"
     minimum_protocol_version = "TLSv1.2_2021"
}

  depends_on = [aws_lambda_function.versioned_uri_rewriter]
}

resource "aws_route53_record" "cdn_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "static" # This makes it static.studysite.shop
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# S3 Bucket Policy for CloudFront OAC
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowCloudFrontOAC",
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.bucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn"    = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}",
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
depends_on = [aws_cloudfront_distribution.cdn]
}
