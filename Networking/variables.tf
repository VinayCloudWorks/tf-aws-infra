variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use for credentials"
  type        = string
}

variable "availability_zones" {
  description = "List of Availability Zones (order matters)"
  type        = list(string)
}

variable "vpcs" {
  description = "Map of VPC definitions. Add additional entries to create more VPCs."
  type = map(object({
    vpc_cidr             = string
    vpc_name             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
  }))
}
