###########################
# Diagnostic outputs for VPC debugging
###########################
output "security_group_vpc_id" {
  value = aws_security_group.app_sg.vpc_id
}

output "lb_security_group_vpc_id" {
  value = aws_security_group.lb_sg.vpc_id
}

output "db_security_group_vpc_id" {
  value = aws_security_group.db_sg.vpc_id
}

output "public_subnet_vpc_ids" {
  value = {
    for key, subnet in aws_subnet.public : key => subnet.vpc_id
  }
}

output "private_subnet_vpc_ids" {
  value = {
    for key, subnet in aws_subnet.private : key => subnet.vpc_id
  }
}

output "asg_subnets" {
  value = [
    for subnet_key, subnet in aws_subnet.public :
    subnet.id if contains(split("-", subnet_key), local.primary_vpc_key)
  ]
}

output "primary_vpc_key" {
  value = local.primary_vpc_key
}

output "primary_vpc_id" {
  value = aws_vpc.main[local.primary_vpc_key].id
}