###########################
# Route53 Records
###########################
data "aws_route53_zone" "selected" {
  name         = "${var.env}.${var.domain_name}"
  private_zone = false
}

resource "aws_route53_record" "app_domain" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.env}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}