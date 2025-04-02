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

variable "db_password" {
  description = "Password for the RDS instance master user"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Database master username"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "env" {
  description = "Environment (dev or demo)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "demo"], var.env)
    error_message = "Environment must be either 'dev' or 'demo'."
  }
}

variable "domain_name" {
  description = "Domain name for Route53 configuration"
  type        = string
}

variable "scale_up_threshold" {
  description = "CPU percentage threshold for scaling up"
  type        = number
  default     = 5
}

variable "scale_down_threshold" {
  description = "CPU percentage threshold for scaling down"
  type        = number
  default     = 3
}

variable "cooldown_period" {
  description = "Cooldown period in seconds for auto scaling"
  type        = number
  default     = 60
}