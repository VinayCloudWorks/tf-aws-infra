terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments_enc" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

###########################
# DB Security Group for the RDS Instance
###########################
resource "aws_security_group" "db_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main[keys(aws_vpc.main)[0]].id

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
}

###########################
# RDS Subnet Group (using private subnets)
###########################
resource "aws_db_subnet_group" "csye6225_subnet_group" {
  name        = "csye6225-subnet-group"
  subnet_ids  = values(aws_subnet.private)[*].id
  description = "Subnet group for csye6225 RDS instance"
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
  password               = var.db_password
  db_name                = var.db_name
  port                   = var.db_port
  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.csye6225_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  parameter_group_name   = aws_db_parameter_group.custom.name
  skip_final_snapshot    = true
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
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_instance_profile" "ec2_role_profile" {
  name = "csye6225-ec2-profile"
  role = aws_iam_role.ec2_role.name
}