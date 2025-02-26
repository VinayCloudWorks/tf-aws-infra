variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use for credentials"
  type        = string
}

variable "dev_account_id" {
  description = "AWS account ID of the dev account that owns the shared AMI"
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

# New variables for the EC2 instance and application
variable "key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
}

variable "app_port" {
  description = "Port on which the application runs"
  type        = number
  default     = 3000
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
