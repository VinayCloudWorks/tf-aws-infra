###########################
# Load Balancer Security Group
###########################
resource "aws_security_group" "lb_sg" {
  name        = "load-balancer-security-group"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.main[keys(aws_vpc.main)[0]].id

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

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LoadBalancerSG"
  }
}

###########################
# Update Application Security Group - Remove direct internet access
###########################
# Note: This resource replaces the one in main.tf
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
    description     = "Allow Application Port from Load Balancer"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebAppSG"
  }
}