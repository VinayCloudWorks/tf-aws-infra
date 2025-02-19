# Terraform AWS Infrastructure Setup


---

## Learning Objectives

- Understand and configure AWS networking components (VPC, Subnets, Internet Gateway, Route Tables).
- Implement Infrastructure as Code (IaC) using Terraform.
- Learn how to parameterize configurations (avoid hardcoding values).
- Set up GitHub repository with branch protection and continuous integration (CI) using GitHub Actions.
- Integrate AWS CLI for managing AWS resources locally.

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
