# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  # Make sure this resource is created before other resources that depend on it
  lifecycle {
    create_before_destroy = true
  }
}