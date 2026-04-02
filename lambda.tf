# ==================== Lambda Functions ====================

# 1. Upload Lambda
resource "aws_lambda_function" "upload" {
  filename         = "lambda/upload.zip"     # We'll create this zip next
  function_name    = "${var.project_name}-upload"
  role             = aws_iam_role.lambda_upload_role.arn
  handler          = "upload.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.vault_files.id
      TABLE_NAME  = aws_dynamodb_table.documents.name
    }
  }

  depends_on = [aws_iam_role_policy.upload_lambda_policy]
}

# 2. Share Link Lambda
resource "aws_lambda_function" "share" {
  filename         = "lambda/share.zip"
  function_name    = "${var.project_name}-share"
  role             = aws_iam_role.lambda_share_role.arn
  handler          = "share.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.documents.name
    }
  }

  depends_on = [aws_iam_role_policy.share_lambda_policy]
}

# 3. Download Lambda
resource "aws_lambda_function" "download" {
  filename         = "lambda/download.zip"
  function_name    = "${var.project_name}-download"
  role             = aws_iam_role.lambda_share_role.arn   # reusing share role for now
  handler          = "download.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.vault_files.id
      TABLE_NAME  = aws_dynamodb_table.documents.name
    }
  }

  depends_on = [aws_iam_role_policy.share_lambda_policy]
}