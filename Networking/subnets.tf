locals {
  public_subnets = flatten([
    for vpc_key, vpc in var.vpcs : [
      for idx, cidr in vpc.public_subnet_cidrs : {
        vpc_key  = vpc_key
        cidr     = cidr
        az       = var.availability_zones[idx]
        vpc_name = vpc.vpc_name
      }
    ]
  ])

  private_subnets = flatten([
    for vpc_key, vpc in var.vpcs : [
      for idx, cidr in vpc.private_subnet_cidrs : {
        vpc_key  = vpc_key
        cidr     = cidr
        az       = var.availability_zones[idx]
        vpc_name = vpc.vpc_name
      }
    ]
  ])
}

resource "aws_subnet" "public" {
  for_each = { for subnet in local.public_subnets : "${subnet.vpc_key}-${subnet.az}" => subnet }

  vpc_id                  = aws_vpc.main[each.value.vpc_key].id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name    = "${each.value.vpc_name}-public-${each.value.az}"
    vpc_key = each.value.vpc_key
  }
}

resource "aws_subnet" "private" {
  for_each = { for subnet in local.private_subnets : "${subnet.vpc_key}-${subnet.az}" => subnet }

  vpc_id                  = aws_vpc.main[each.value.vpc_key].id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name    = "${each.value.vpc_name}-private-${each.value.az}"
    vpc_key = each.value.vpc_key
  }
}
