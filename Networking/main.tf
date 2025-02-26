terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Data source to retrieve the latest custom AMI whose name starts with "webappAMI"
data "aws_ami" "webapp" {
  most_recent = true

  filter {
    name   = "name"
    values = ["webappAMI*"]
  }

  owners = [var.dev_account_id]
}

# Application Security Group for the EC2 instance
resource "aws_security_group" "app_sg" {
  name        = "application-security-group"
  description = "Security group for web application EC2 instances"

  # Reference the first VPC from the vpcs map defined in vpc.tf
  vpc_id = aws_vpc.main[keys(aws_vpc.main)[0]].id

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
    from_port   = var.app_port # Application port (3000)
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

# EC2 Instance using the latest custom AMI
resource "aws_instance" "app_instance" {
  ami           = data.aws_ami.webapp.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # Choose a public subnet from the public subnets map (selecting the first one)
  subnet_id = aws_subnet.public[keys(aws_subnet.public)[0]].id

  vpc_security_group_ids = [aws_security_group.app_sg.id]

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
