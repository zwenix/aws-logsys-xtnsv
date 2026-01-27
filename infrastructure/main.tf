terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# DynamoDB Table for Log Storage
resource "aws_dynamodb_table" "logs" {
  name           = "${var.project_name}-${var.environment}-logs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "logId"
  range_key      = "timestamp"

  attribute {
    name = "logId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "type"
    type = "S"
  }

  # Global Secondary Index for efficient time-based queries
  global_secondary_index {
    name            = "TimestampIndex"
    hash_key        = "type"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery for production
  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-logs-table"
  }
}

# IAM Role for Ingest Lambda
resource "aws_iam_role" "ingest_lambda_role" {
  name = "${var.project_name}-${var.environment}-ingest-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ingest-lambda-role"
  }
}

# IAM Policy for Ingest Lambda - DynamoDB Write Access
resource "aws_iam_role_policy" "ingest_lambda_dynamodb_policy" {
  name = "${var.project_name}-${var.environment}-ingest-dynamodb-policy"
  role = aws_iam_role.ingest_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.logs.arn
      }
    ]
  })
}

# CloudWatch Logs Policy for Ingest Lambda
resource "aws_iam_role_policy_attachment" "ingest_lambda_logs" {
  role       = aws_iam_role.ingest_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Role for ReadRecent Lambda
resource "aws_iam_role" "read_recent_lambda_role" {
  name = "${var.project_name}-${var.environment}-read-recent-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-read-recent-lambda-role"
  }
}

# IAM Policy for ReadRecent Lambda - DynamoDB Read Access
resource "aws_iam_role_policy" "read_recent_lambda_dynamodb_policy" {
  name = "${var.project_name}-${var.environment}-read-recent-dynamodb-policy"
  role = aws_iam_role.read_recent_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.logs.arn,
          "${aws_dynamodb_table.logs.arn}/index/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs Policy for ReadRecent Lambda
resource "aws_iam_role_policy_attachment" "read_recent_lambda_logs" {
  role       = aws_iam_role.read_recent_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Archive Lambda code for Ingest function
data "archive_file" "ingest_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/ingest"
  output_path = "${path.module}/.terraform/ingest_lambda.zip"
}

# Ingest Lambda Function
resource "aws_lambda_function" "ingest" {
  filename         = data.archive_file.ingest_lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-ingest"
  role            = aws_iam_role.ingest_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.ingest_lambda_zip.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      ENVIRONMENT         = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ingest-lambda"
  }
}

# Lambda Function URL for Ingest
resource "aws_lambda_function_url" "ingest" {
  function_name      = aws_lambda_function.ingest.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["content-type"]
    max_age           = 86400
  }
}

# CloudWatch Log Group for Ingest Lambda
resource "aws_cloudwatch_log_group" "ingest_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-ingest-logs"
  }
}

# Archive Lambda code for ReadRecent function
data "archive_file" "read_recent_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/read_recent"
  output_path = "${path.module}/.terraform/read_recent_lambda.zip"
}

# ReadRecent Lambda Function
resource "aws_lambda_function" "read_recent" {
  filename         = data.archive_file.read_recent_lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-read-recent"
  role            = aws_iam_role.read_recent_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.read_recent_lambda_zip.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.logs.name
      ENVIRONMENT         = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-read-recent-lambda"
  }
}

# Lambda Function URL for ReadRecent
resource "aws_lambda_function_url" "read_recent" {
  function_name      = aws_lambda_function.read_recent.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["content-type"]
    max_age           = 86400
  }
}

# CloudWatch Log Group for ReadRecent Lambda
resource "aws_cloudwatch_log_group" "read_recent_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.read_recent.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-read-recent-logs"
  }
}
