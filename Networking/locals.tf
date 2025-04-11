locals {
  # Explicitly set the primary VPC key to the first key in var.vpcs
  primary_vpc_key = keys(var.vpcs)[0] # This will be "vpc1" based on your dev.tfvars
}