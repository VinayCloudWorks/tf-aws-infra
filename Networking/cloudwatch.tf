###########################
# CloudWatch IAM Policy for EC2
###########################
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "csye6225-cloudwatch-policy"
  description = "Policy for EC2 instance to access CloudWatch services"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter"],
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

# Attach CloudWatch policy to the existing EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

###########################
# CloudWatch Log Groups
###########################
resource "aws_cloudwatch_log_group" "webapp_logs" {
  name              = "webapp-logs"
  retention_in_days = 7
  tags = {
    Environment = var.env
    Application = "WebApp"
  }
}

resource "aws_cloudwatch_log_group" "webapp_system_logs" {
  name              = "webapp-system-logs"
  retention_in_days = 7
  tags = {
    Environment = var.env
    Application = "WebApp"
  }
}