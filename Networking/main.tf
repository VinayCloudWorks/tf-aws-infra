terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Retrieve the latest custom AMI whose name starts with "webappAMI"
data "aws_ami" "webapp" {
  most_recent = true

  filter {
    name   = "name"
    values = ["webappAMI*"]
  }

  owners = [var.dev_account_id]
}

###########################
# S3 Bucket for Attachments
###########################
resource "random_uuid" "bucket_uuid" {}

resource "aws_s3_bucket" "attachments" {
  bucket        = random_uuid.bucket_uuid.result
  force_destroy = true

  tags = {
    Name = "AttachmentsBucket"
  }
}

# Use separate resource for lifecycle configuration (avoiding deprecated inline lifecycle_rule)
resource "aws_s3_bucket_lifecycle_configuration" "attachments_lifecycle" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    id     = "transition_to_standard_ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket.attachments]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments_enc" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [aws_s3_bucket.attachments]
}

###########################
# DB Security Group for the RDS Instance
###########################
resource "aws_security_group" "db_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main[local.primary_vpc_key].id

  ingress {
    description     = "Allow DB access from app security group"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_security_group.app_sg]
}

###########################
# RDS Parameter Group (Custom)
###########################
resource "aws_db_parameter_group" "custom" {
  name        = "csye6225-parameter-group"
  family      = "mysql8.0"
  description = "Custom parameter group for csye6225 RDS instance"

  parameter {
    name         = "time_zone"
    value        = "UTC"
    apply_method = "immediate"
  }

  # Add this parameter to improve connection handling
  parameter {
    name         = "skip_name_resolve"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Add these parameters to improve connection handling with special characters
  parameter {
    name         = "character_set_server"
    value        = "utf8mb4"
    apply_method = "immediate"
  }

  parameter {
    name         = "character_set_client"
    value        = "utf8mb4"
    apply_method = "immediate"
  }
}

###########################
# RDS Subnet Group (using private subnets)
###########################
resource "aws_db_subnet_group" "csye6225_subnet_group" {
  name        = "csye6225-subnet-group"
  subnet_ids  = values(aws_subnet.private)[*].id
  description = "Subnet group for csye6225 RDS instance"

  depends_on = [aws_subnet.private]
}

###########################
# RDS Instance
###########################
resource "aws_db_instance" "csye6225" {
  identifier             = "csye6225"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = var.db_username
  password               = random_password.db_password.result # Use the random password
  db_name                = var.db_name
  port                   = var.db_port
  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.csye6225_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  parameter_group_name   = aws_db_parameter_group.custom.name
  skip_final_snapshot    = true
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_key.arn # Use the RDS KMS key

  depends_on = [
    aws_db_subnet_group.csye6225_subnet_group,
    aws_security_group.db_sg,
    aws_db_parameter_group.custom,
    random_password.db_password,
    aws_kms_key.rds_key
  ]
}

###########################
# Configure MySQL User Permissions
###########################
resource "null_resource" "setup_mysql_user" {
  depends_on = [
    aws_db_instance.csye6225,
    aws_secretsmanager_secret_version.db_credentials_version,
    random_password.db_password
  ]

  # This will run on each apply to ensure the permissions are set
  triggers = {
    rds_endpoint     = aws_db_instance.csye6225.endpoint
    password_version = random_password.db_password.result
  }

  provisioner "local-exec" {
    # This script grants access to the DB user from any host (%)
    command = <<-EOF
      # Wait for RDS to be fully available
      sleep 60
      
      # Install MySQL client if needed
      if ! command -v mysql &> /dev/null; then
        echo "MySQL client not found. Installing..."
        sudo apt-get update && sudo apt-get install -y mysql-client || true
      fi
      
      # Create the user for any host and grant permissions
      echo "Configuring MySQL user permissions..."
      mysql -h ${aws_db_instance.csye6225.address} -u ${var.db_username} -p'${random_password.db_password.result}' -e "CREATE USER IF NOT EXISTS '${var.db_username}'@'%' IDENTIFIED BY '${random_password.db_password.result}'; GRANT ALL PRIVILEGES ON *.* TO '${var.db_username}'@'%'; FLUSH PRIVILEGES;" || echo "Failed to configure MySQL permissions - may already be configured"
      
      # Create specific permissions for VPC CIDR range
      mysql -h ${aws_db_instance.csye6225.address} -u ${var.db_username} -p'${random_password.db_password.result}' -e "CREATE USER IF NOT EXISTS '${var.db_username}'@'10.%' IDENTIFIED BY '${random_password.db_password.result}'; GRANT ALL PRIVILEGES ON *.* TO '${var.db_username}'@'10.%'; FLUSH PRIVILEGES;" || echo "Failed to configure 10.% permissions"
    EOF
  }
}

###########################
# Wait for RDS to be fully available
###########################
resource "null_resource" "wait_for_db" {
  depends_on = [aws_db_instance.csye6225, null_resource.setup_mysql_user]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting additional time for RDS instance to be fully available..."
      sleep 30
      echo "Proceeding with deployment."
    EOT
  }
}

###########################
# IAM Role & Policy for EC2 (S3 Access)
###########################
resource "aws_iam_role" "ec2_role" {
  name = "csye6225-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

###########################
# IAM Policy for S3 Access
###########################
resource "aws_iam_policy" "s3_access" {
  name        = "csye6225-s3-access"
  description = "Policy for EC2 instance to access S3 bucket attachments"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.attachments.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource = ["${aws_s3_bucket.attachments.arn}/*"]
      }
    ]
  })

  depends_on = [aws_s3_bucket.attachments]
}

###########################
# IAM Policy for RDS Information Access
###########################
resource "aws_iam_policy" "rds_info_access" {
  name        = "csye6225-rds-info-access"
  description = "Policy to allow EC2 to describe RDS instances for fallback connection"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:DescribeDBInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

###########################
# Attach Policies to Role
###########################
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn

  depends_on = [aws_iam_role.ec2_role, aws_iam_policy.s3_access]
}

resource "aws_iam_role_policy_attachment" "attach_rds_info_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.rds_info_access.arn

  depends_on = [aws_iam_role.ec2_role, aws_iam_policy.rds_info_access]
}

resource "aws_iam_instance_profile" "ec2_role_profile" {
  name = "csye6225-ec2-profile"
  role = aws_iam_role.ec2_role.name

  depends_on = [
    aws_iam_role.ec2_role,
    aws_iam_role_policy_attachment.attach_s3_policy,
    aws_iam_role_policy_attachment.attach_rds_info_policy,
    aws_iam_role_policy_attachment.attach_kms_policy,
    aws_iam_role_policy_attachment.attach_cloudwatch_policy,
    aws_iam_role_policy_attachment.attach_secrets_policy
  ]
}