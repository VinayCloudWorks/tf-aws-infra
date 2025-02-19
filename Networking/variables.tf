variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for credentials"
  type        = string
  default     = "dev"
}

variable "availability_zones" {
  description = "List of Availability Zones (order matters)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpcs" {
  description = "Map of VPC definitions. Add additional entries to create more VPCs."
  type = map(object({
    vpc_cidr             = string
    vpc_name             = string
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
  }))
  default = {
    vpc1 = {
      vpc_cidr             = "10.0.0.0/16"
      vpc_name             = "my-vpc"
      public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    },
    vpc2 = {
      vpc_cidr             = "10.0.0.0/16"
      vpc_name             = "my-vpc"
      public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    }
  }
}
