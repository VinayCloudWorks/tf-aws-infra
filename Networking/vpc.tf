resource "aws_vpc" "main" {
  for_each = var.vpcs

  cidr_block           = each.value.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = each.value.vpc_name
  }
}
