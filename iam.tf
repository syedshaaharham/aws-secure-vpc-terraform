# ==================== Lambda Execution Roles ====================

# Role for Upload Lambda
resource "aws_iam_role" "lambda_upload_role" {
  name = "${var.project_name}-upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Role for Download/Share Lambda
resource "aws_iam_role" "lambda_share_role" {
  name = "${var.project_name}-share-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Basic Lambda logging permission (common for both)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  for_each = toset([aws_iam_role.lambda_upload_role.name, aws_iam_role.lambda_share_role.name])

  role       = each.key
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Upload Lambda Permissions
resource "aws_iam_role_policy" "upload_lambda_policy" {
  name = "${var.project_name}-upload-policy"
  role = aws_iam_role.lambda_upload_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.vault_files.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.documents.arn
      },
      {
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey"
        Resource = aws_kms_key.vault_key.arn
      }
    ]
  })
}

# Share/Download Lambda Permissions
resource "aws_iam_role_policy" "share_lambda_policy" {
  name = "${var.project_name}-share-policy"
  role = aws_iam_role.lambda_share_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.vault_files.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.documents.arn,
          "${aws_dynamodb_table.documents.arn}/index/UserIdIndex"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.vault_key.arn
      }
    ]
  })
}