###########################
# Secrets Manager for Database Credentials
###########################
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.env}-db-credentials"
  description             = "Database credentials for ${var.env} environment"
  kms_key_id              = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 0

  tags = {
    Name        = "DBCredentials"
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result # Use the random password
    engine   = "mysql"
    host     = aws_db_instance.csye6225.address
    port     = var.db_port
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.csye6225, random_password.db_password]
}

# NOTE: The IAM policies for accessing Secrets Manager are in kms.tf
# They are attached to the EC2 role there, so we don't need to duplicate them here.