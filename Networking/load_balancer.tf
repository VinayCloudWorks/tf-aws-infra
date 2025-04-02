###########################
# Application Load Balancer
###########################
resource "aws_lb" "app_lb" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = values(aws_subnet.public)[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "WebAppLoadBalancer"
    Environment = var.env
  }
}

###########################
# Target Group for Load Balancer
###########################
resource "aws_lb_target_group" "app_tg" {
  name     = "webapp-target-group"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main[keys(aws_vpc.main)[0]].id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "WebAppTargetGroup"
  }
}

###########################
# Load Balancer Listener
###########################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}