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
# Application Security Group for the EC2 Instance
###########################
resource "aws_security_group" "app_sg" {
  name        = "application-security-group"
  description = "Security group for web application EC2 instances"
  vpc_id      = aws_vpc.main[keys(aws_vpc.main)[0]].id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Application Port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

###########################
# EC2 Instance with User Data Script
###########################
resource "aws_instance" "app_instance" {
  ami                    = data.aws_ami.webapp.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public[keys(aws_subnet.public)[0]].id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_role_profile.name

  user_data = <<-EOF
#!/bin/bash
# Export database configuration for the web application
echo "DB_HOST=${aws_db_instance.csye6225.address}" >> /etc/environment
echo "DB_USER=${var.db_username}" >> /etc/environment
echo "DB_PASSWORD=${var.db_password}" >> /etc/environment
echo "DB_NAME=${var.db_name}" >> /etc/environment
echo "DB_PORT=${var.db_port}" >> /etc/environment
# Export S3 bucket name for file storage
echo "S3_BUCKET_NAME=${aws_s3_bucket.attachments.bucket}" >> /etc/environment

# Create directories for CloudWatch agent
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo mkdir -p /var/log/webapp

# Install CloudWatch agent
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Create log directories with proper permissions
sudo touch /var/log/webapp/application.log
sudo touch /var/log/webapp/error.log
sudo chown csye6225:csye6225 /var/log/webapp/*
sudo chmod 664 /var/log/webapp/*

# Create CloudWatch agent configuration file
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/webapp/application.log",
            "log_group_name": "webapp-logs",
            "log_stream_name": "{instance_id}-application-log",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/webapp/error.log",
            "log_group_name": "webapp-logs",
            "log_stream_name": "{instance_id}-error-log",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "webapp-system-logs",
            "log_stream_name": "{instance_id}-syslog",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "WebApp",
    "metrics_collected": {
      "statsd": {
        "service_address": ":8125",
        "metrics_collection_interval": 10,
        "metrics_aggregation_interval": 60
      },
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["disk_used_percent"]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    }
  }
}
CWCONFIG

# Add the instance ID to environment for CloudWatch agent
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "EC2_INSTANCE_ID=$EC2_INSTANCE_ID" >> /etc/opt/csye6225/env.conf

# Configure CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Create a custom environment file for the service using a different approach to avoid heredoc issues
sudo mkdir -p /etc/opt/csye6225
cat > /tmp/env.conf << 'ENDOFFILE'
DB_HOST=DB_HOST_VALUE
DB_USER=DB_USER_VALUE
DB_PASSWORD=DB_PASSWORD_VALUE
DB_PASS=DB_PASS_VALUE
MYSQL_PASSWORD=MYSQL_PASSWORD_VALUE
PASSWORD=PASSWORD_VALUE
DB_NAME=DB_NAME_VALUE
DB_PORT=DB_PORT_VALUE
S3_BUCKET_NAME=S3_BUCKET_VALUE
DB_DIALECT=mysql
PORT=3000
ENDOFFILE

# Replace placeholders with actual values
sed -i "s|DB_HOST_VALUE|${aws_db_instance.csye6225.address}|g" /tmp/env.conf
sed -i "s|DB_USER_VALUE|${var.db_username}|g" /tmp/env.conf
sed -i "s|DB_PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|DB_PASS_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|MYSQL_PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|DB_NAME_VALUE|${var.db_name}|g" /tmp/env.conf
sed -i "s|DB_PORT_VALUE|${var.db_port}|g" /tmp/env.conf
sed -i "s|S3_BUCKET_VALUE|${aws_s3_bucket.attachments.bucket}|g" /tmp/env.conf

# Move the file to its final destination
sudo mv /tmp/env.conf /etc/opt/csye6225/env.conf

# Make sure the environment file is readable by the app user
sudo chmod 644 /etc/opt/csye6225/env.conf
sudo chown root:csye6225 /etc/opt/csye6225/env.conf || true

# Create systemd override directory
sudo mkdir -p /etc/systemd/system/app.service.d/

# Create systemd override file to use env.conf
cat > /tmp/override.conf << 'ENDOFCONF'
[Service]
EnvironmentFile=/etc/opt/csye6225/env.conf
ENDOFCONF
sudo mv /tmp/override.conf /etc/systemd/system/app.service.d/override.conf

# Fix deprecated syslog settings
sudo sed -i 's/StandardOutput=syslog/StandardOutput=journal/' /etc/systemd/system/app.service
sudo sed -i 's/StandardError=syslog/StandardError=journal/' /etc/systemd/system/app.service

# Log for debugging
echo "Setup completed at $(date)" > /var/log/app-setup.log
echo "RDS endpoint: ${aws_db_instance.csye6225.address}" >> /var/log/app-setup.log
cat /etc/opt/csye6225/env.conf >> /var/log/app-setup.log

# Reload systemd configuration and start the application service
sudo systemctl daemon-reload
sudo systemctl restart app.service
EOF

  disable_api_termination = false

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name = "WebAppInstance"
  }
}