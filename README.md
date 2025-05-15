# AWS Cloud Architecture Terraform Project

## Overview
This project automates the setup of AWS networking infrastructure using Terraform and integrates it with GitHub Actions for Continuous Integration (CI) to ensure proper formatting and validation of Terraform configurations.

## Requirements
Before running the Terraform configuration or the GitHub Actions workflow, ensure you have the following:
- Terraform (1.5.0 or higher recommended)
- AWS CLI installed and configured with a profile

## Running Terraform Locally
To run Terraform locally, follow these steps:

1. **Set the AWS Region Environment Variable**
   ```bash
   export AWS_REGION=us-east-1  # Replace with your preferred region
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Format and Validate Terraform Files**
   ```bash
   terraform fmt -check -recursive
   terraform validate
   ```

4. **Plan the Deployment**
   ```bash
   terraform plan -out=tfplan
   ```

5. **Apply the Configuration**
   ```bash
   terraform apply tfplan
   ```
   
## Certificate Management
To import an SSL certificate into AWS Certificate Manager (ACM), use the following command:

```bash
aws acm import-certificate \
--certificate fileb://demo_vinaysathe_me.crt \
--certificate-chain fileb://demo_vinaysathe_me.ca-bundle \
--private-key fileb://private.key \
--region us-east-1 \
--profile demo
```

![Architecture Diagram](Architecture%20Diagram.png)
