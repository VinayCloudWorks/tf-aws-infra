###########################
# SSL Certificate
###########################
# For dev environment, use AWS Certificate Manager
resource "aws_acm_certificate" "ssl_cert" {
  count             = var.env == "dev" ? 1 : 0
  domain_name       = "${var.env}.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Name        = "WebAppSSLCert"
    Environment = var.env
  }

  lifecycle {
    create_before_destroy = true
  }
}

# For dev environment, create DNS validation record
resource "aws_route53_record" "cert_validation" {
  count   = var.env == "dev" ? 1 : 0
  name    = tolist(aws_acm_certificate.ssl_cert[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.ssl_cert[0].domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.selected.zone_id
  records = [tolist(aws_acm_certificate.ssl_cert[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

# For dev environment, validate the certificate
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.env == "dev" ? 1 : 0
  certificate_arn         = aws_acm_certificate.ssl_cert[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
}

# For demo environment, use imported certificate
# Note: This is a data source to reference the certificate already imported via CLI
data "aws_acm_certificate" "imported_cert" {
  count       = var.env == "demo" ? 1 : 0
  domain      = "${var.env}.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

###########################
# Application Load Balancer
###########################
resource "aws_lb" "app_lb" {
  name                       = "webapp-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb_sg.id]
  subnets                    = values(aws_subnet.public)[*].id
  enable_deletion_protection = false

  # Add dependency on RDS to ensure networking is ready
  # and RDS is available before load balancer is created
  depends_on = [
    aws_db_instance.csye6225,
    null_resource.wait_for_db
  ]

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

  # Depend on the load balancer
  depends_on = [aws_lb.app_lb]

  tags = {
    Name = "WebAppTargetGroup"
  }
}

###########################
# Load Balancer Listeners
###########################
# HTTP Listener - only for health checks
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  depends_on = [aws_lb.app_lb, aws_lb_target_group.app_tg]
}

# HTTPS Listener with SSL certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.env == "dev" ? aws_acm_certificate.ssl_cert[0].arn : data.aws_acm_certificate.imported_cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  # Fixed dependencies - removed conditional expression from depends_on
  depends_on = [
    aws_lb.app_lb,
    aws_lb_target_group.app_tg
  ]
}