
# PROVIDER
provider "aws" {
  region = "eu-west-2"
}

# Get current AWS account ID dynamically
data "aws_caller_identity" "current" {}


# S3 BUCKET

resource "aws_s3_bucket" "iceberg" {
  bucket = "oyin-banking-iceberg-warehouse"

  tags = {
    Project     = "banking-data-platform"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_public_access_block" "iceberg" {
  bucket = aws_s3_bucket.iceberg.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "iceberg" {
  bucket = aws_s3_bucket.iceberg.id
  versioning_configuration {
    status = "Enabled"
  }
}


# IAM USER — for Spark to access S3

resource "aws_iam_user" "spark" {
  name = "banking-spark-user"
}

resource "aws_iam_access_key" "spark" {
  user = aws_iam_user.spark.name
}

resource "aws_iam_user_policy" "spark_s3" {
  name = "banking-spark-s3-policy"
  user = aws_iam_user.spark.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.iceberg.arn,
          "${aws_s3_bucket.iceberg.arn}/*"
        ]
      }
    ]
  })
}


# IAM ROLE — for Snowflake to access S3

resource "aws_iam_role" "snowflake" {
  name = "snowflake-s3-role"

  assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Principal = {
        AWS = var.snowflake_iam_user_arn
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.snowflake_external_id
        }
      }
    }
  ]
  })
}

resource "aws_iam_role_policy" "snowflake_s3" {
  name = "snowflake-s3-policy"
  role = aws_iam_role.snowflake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.iceberg.arn,
          "${aws_s3_bucket.iceberg.arn}/*"
        ]
      }
    ]
  })
}


# OUTPUTS

output "bucket_name" {
  value = aws_s3_bucket.iceberg.id
}

output "spark_access_key" {
  value     = aws_iam_access_key.spark.id
  sensitive = true
}

output "spark_secret_key" {
  value     = aws_iam_access_key.spark.secret
  sensitive = true
}

output "snowflake_role_arn" {
  value = aws_iam_role.snowflake.arn
}

resource "local_file" "env" {
  filename = "../../.env"
  content  = <<-EOT
    AWS_ACCESS_KEY_ID=${aws_iam_access_key.spark.id}
    AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.spark.secret}
    AWS_REGION=eu-west-2
  EOT
}

