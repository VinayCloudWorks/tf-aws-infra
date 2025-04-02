# Terraform AWS Infrastructure Setup


---

## Learning Objectives

- This assignment provisions a custom networking stack, security group, and EC2 instance using Terraform.
- The instance is launched in a custom VPC (not the default), uses a pre-built custom AMI (with name starting with webappAMI-), and is pre-configured to run a web application along with its health-check endpoint.

---

## Pre-requisites

Before you begin, ensure that you have the following installed and configured:
- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Git and GitHub account access
- An AWS account with the proper permissions for creating networking resources

---

## Commands 

   `aws configure --profile profile name`

   `terraform init`

   `terraform fmt`

   `terraform validate`

   `terraform plan`

   `terraform apply -var="aws_profile=dev or demo"`

   `terraform destroy -var="aws_profile=dev or demo"`


## For overriding the availability_zones

`terraform apply -var="aws_region=us-west-2" -var='availability_zones=["us-west-2a","us-west-2b","us-west-2c"]'
`
`dig NS yourdomain.tld`
