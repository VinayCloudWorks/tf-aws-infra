###########################
# KMS Keys for Encryption
###########################
# KMS Key for EC2 Encryption

resource "aws_kms_key" "ec2_key" {
  description             = "KMS key for EC2 encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow CLI User to Manage Keys",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.aws_profile}-cli"
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 and AutoScaling services to use the key",
        Effect = "Allow",
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "autoscaling.amazonaws.com"
          ]
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow AutoScaling service role",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlainText",
          "kms:ReEncrypt*",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "EC2KMSKey"
    Environment = var.env
  }
}

resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/${var.env}-ec2-key"
  target_key_id = aws_kms_key.ec2_key.key_id
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds_key" {
  description             = "KMS key for RDS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  rotation_period_in_days = 90

  tags = {
    Name        = "RDSKMSKey"
    Environment = var.env
  }
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/${var.env}-rds-key"
  target_key_id = aws_kms_key.rds_key.key_id
}

# KMS Key for S3 Encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow CLI User to Manage Keys",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.aws_profile}-cli"
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow S3 service to use the key",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "S3KMSKey"
    Environment = var.env
  }
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.env}-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow CLI User to Manage Keys",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.aws_profile}-cli"
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use the key",
        Effect = "Allow",
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "SecretsKMSKey"
    Environment = var.env
  }
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.env}-secrets-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

###########################
# IAM Policy for KMS Access
###########################
resource "aws_iam_policy" "kms_access" {
  name        = "csye6225-kms-access"
  description = "Policy for EC2 instance to use KMS keys"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlainText",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey"
        ],
        Resource = [
          aws_kms_key.ec2_key.arn,
          aws_kms_key.s3_key.arn,
          aws_kms_key.secrets_key.arn
        ]
      }
    ]
  })
}

# Additional policy for CloudWatch access
resource "aws_iam_policy" "cloudwatch_access" {
  name        = "csye6225-cloudwatch-access"
  description = "Policy for EC2 instance to send logs to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

###########################
# IAM Policy for Secrets Manager Access
###########################
resource "aws_iam_policy" "secrets_manager_access" {
  name        = "csye6225-secrets-manager-access"
  description = "Policy to allow EC2 to access database credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}-db-credentials*"
        ]
      }
    ]
  })
}

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "attach_kms_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.kms_access.arn
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_access.arn
}

resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

# Add this data source to get the account ID
data "aws_caller_identity" "current" {}