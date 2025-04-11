###########################
# Launch Template
###########################
resource "aws_launch_template" "app_launch_template" {
  name                   = "csye6225_asg"
  image_id               = data.aws_ami.webapp.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Ensure RDS, Secrets Manager, and Load Balancer resources are created first
  depends_on = [
    aws_db_instance.csye6225,
    aws_secretsmanager_secret_version.db_credentials_version,
    null_resource.wait_for_db,
    aws_lb.app_lb,
    aws_lb_target_group.app_tg,
    aws_lb_listener.http,
    aws_lb_listener.https
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_role_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 25
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_key.arn
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
# Set up logging for debugging
exec > /var/log/user-data.log 2>&1
echo "Starting user data script execution at $(date)"

# Install dependencies
apt-get update -y
apt-get install -y jq unzip curl mysql-client

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip
echo "AWS CLI installed: $(aws --version)"

# Retrieve database credentials from Secrets Manager
echo "Retrieving database credentials from Secrets Manager..."
SECRET_DATA=$(aws secretsmanager get-secret-value \
  --secret-id ${var.env}-db-credentials \
  --region ${var.aws_region} \
  --query SecretString \
  --output text)

# Extract values using jq
if [ -n "$SECRET_DATA" ]; then
  echo "Successfully retrieved secret data from Secrets Manager"
  DB_PASSWORD=$(echo $SECRET_DATA | jq -r '.password')
  DB_HOST=$(echo $SECRET_DATA | jq -r '.host // "${aws_db_instance.csye6225.address}"')
  DB_USER=$(echo $SECRET_DATA | jq -r '.username // "${var.db_username}"')
  DB_NAME=$(echo $SECRET_DATA | jq -r '.dbname // "${var.db_name}"')
  DB_PORT=$(echo $SECRET_DATA | jq -r '.port // "${var.db_port}"')
else
  echo "Failed to retrieve data from Secrets Manager. Using RDS connection data without password."
  # Only set non-sensitive values
  DB_HOST="${aws_db_instance.csye6225.address}"
  DB_USER="${var.db_username}"
  DB_NAME="${var.db_name}"
  DB_PORT="${var.db_port}"
  # Password will be left empty - application will fail but won't expose credentials
  DB_PASSWORD=""
  echo "ERROR: Could not retrieve database password. Application will not function correctly."
fi

# Directly export non-sensitive variables to /etc/environment
echo "Setting up environment variables in /etc/environment"
echo "DB_HOST=$DB_HOST" >> /etc/environment
echo "DB_USER=$DB_USER" >> /etc/environment
echo "DB_NAME=$DB_NAME" >> /etc/environment
echo "DB_PORT=$DB_PORT" >> /etc/environment
echo "S3_BUCKET_NAME=${aws_s3_bucket.attachments.bucket}" >> /etc/environment
echo "DB_DIALECT=mysql" >> /etc/environment
echo "PORT=3000" >> /etc/environment

# Get EC2 metadata
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "EC2_INSTANCE_ID=$EC2_INSTANCE_ID" >> /etc/environment
echo "EC2_AVAILABILITY_ZONE=$EC2_AVAILABILITY_ZONE" >> /etc/environment

# Create application-specific dotenv file with placeholders
mkdir -p /opt/csye6225
cat > /tmp/app.env << 'ENDOFFILE'
DB_HOST=DB_HOST_VALUE
DB_USER=DB_USER_VALUE
DB_PASS=DB_PASS_VALUE
DB_PASSWORD=DB_PASS_VALUE
DB_NAME=DB_NAME_VALUE
DB_PORT=DB_PORT_VALUE
S3_BUCKET_NAME=S3_BUCKET_VALUE
DB_DIALECT=mysql
PORT=3000
ENDOFFILE

# Replace placeholders with actual values
sed -i "s|DB_HOST_VALUE|$DB_HOST|g" /tmp/app.env
sed -i "s|DB_USER_VALUE|$DB_USER|g" /tmp/app.env
sed -i "s|DB_PASS_VALUE|$DB_PASSWORD|g" /tmp/app.env
sed -i "s|DB_NAME_VALUE|$DB_NAME|g" /tmp/app.env
sed -i "s|DB_PORT_VALUE|$DB_PORT|g" /tmp/app.env
sed -i "s|S3_BUCKET_VALUE|${aws_s3_bucket.attachments.bucket}|g" /tmp/app.env

# Move the app.env file to the application directory
mv /tmp/app.env /opt/csye6225/.env
chmod 644 /opt/csye6225/.env  # Using standard permissions
chown csye6225:csye6225 /opt/csye6225/.env || true

# Create systemd environment file
mkdir -p /etc/opt/csye6225
cat > /tmp/env.conf << 'ENDOFFILE'
DB_HOST=DB_HOST_VALUE
DB_USER=DB_USER_VALUE
DB_PASSWORD=DB_PASS_VALUE
DB_PASS=DB_PASS_VALUE
DB_NAME=DB_NAME_VALUE
DB_PORT=DB_PORT_VALUE
S3_BUCKET_NAME=S3_BUCKET_VALUE
DB_DIALECT=mysql
PORT=3000
EC2_INSTANCE_ID=EC2_ID_VALUE
EC2_AVAILABILITY_ZONE=EC2_AZ_VALUE
ENDOFFILE

# Replace placeholders with actual values
sed -i "s|DB_HOST_VALUE|$DB_HOST|g" /tmp/env.conf
sed -i "s|DB_USER_VALUE|$DB_USER|g" /tmp/env.conf
sed -i "s|DB_PASS_VALUE|$DB_PASSWORD|g" /tmp/env.conf
sed -i "s|DB_NAME_VALUE|$DB_NAME|g" /tmp/env.conf
sed -i "s|DB_PORT_VALUE|$DB_PORT|g" /tmp/env.conf
sed -i "s|S3_BUCKET_VALUE|${aws_s3_bucket.attachments.bucket}|g" /tmp/env.conf
sed -i "s|EC2_ID_VALUE|$EC2_INSTANCE_ID|g" /tmp/env.conf
sed -i "s|EC2_AZ_VALUE|$EC2_AVAILABILITY_ZONE|g" /tmp/env.conf

# Move the env.conf file to the systemd directory
mv /tmp/env.conf /etc/opt/csye6225/env.conf
chmod 644 /etc/opt/csye6225/env.conf  # Using standard permissions

# Create systemd override directory
mkdir -p /etc/systemd/system/app.service.d/

# Create systemd override file
cat > /tmp/override.conf << 'ENDOFFILE'
[Service]
EnvironmentFile=/etc/opt/csye6225/env.conf
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5s
TimeoutStartSec=120
ENDOFFILE
mv /tmp/override.conf /etc/systemd/system/app.service.d/override.conf

# Check for dotenv in server.js and add if missing
cd /opt/csye6225
if ! head -n 1 server.js | grep -q "require('dotenv').config()"; then
  cp server.js server.js.bak
  echo "require('dotenv').config();" > server.js.new
  cat server.js >> server.js.new
  mv server.js.new server.js
  chmod 644 server.js
fi

# Create IMPROVED wrapper script for the application
cat > /tmp/wrapper.sh << 'ENDOFFILE'
#!/bin/bash

# Source the application environment file directly
source /etc/opt/csye6225/env.conf

# Export each variable individually to make sure they're available to the Node.js process
export DB_HOST
export DB_USER
export DB_PASSWORD
export DB_PASS
export DB_NAME
export DB_PORT
export S3_BUCKET_NAME
export DB_DIALECT
export PORT
export EC2_INSTANCE_ID
export EC2_AVAILABILITY_ZONE

# Log what we're using (don't log passwords)
echo "Starting application with:"
echo "DB_HOST=$DB_HOST"
echo "DB_USER=$DB_USER"
echo "DB_NAME=$DB_NAME"
echo "DB_PORT=$DB_PORT"

# Start the application
exec node /opt/csye6225/server.js
ENDOFFILE

# Move the wrapper script to the application directory
mv /tmp/wrapper.sh /opt/csye6225/wrapper.sh
chmod +x /opt/csye6225/wrapper.sh

# Update app.service to use the wrapper script
if [ -f /etc/systemd/system/app.service ]; then
  sed -i 's|ExecStart=.*|ExecStart=/opt/csye6225/wrapper.sh|' /etc/systemd/system/app.service
  # Fix deprecated syslog settings
  sed -i 's/StandardOutput=syslog/StandardOutput=journal/' /etc/systemd/system/app.service
  sed -i 's/StandardError=syslog/StandardError=journal/' /etc/systemd/system/app.service
fi

# Create log directory with proper permissions
# This is essential and was part of our manual fix
echo "Creating log directory with proper permissions"
mkdir -p /var/log/webapp
chown csye6225:csye6225 /var/log/webapp
chmod 755 /var/log/webapp

# Create debug log - Be careful not to log sensitive information
echo "Setup completed at $(date)" > /var/log/app-setup.log
echo "RDS endpoint: $DB_HOST" >> /var/log/app-setup.log
echo "Instance ID: $EC2_INSTANCE_ID" >> /var/log/app-setup.log
echo "Environment variables (excluding passwords):" >> /var/log/app-setup.log
grep -v "PASSWORD\|PASS" /etc/opt/csye6225/env.conf >> /var/log/app-setup.log

# IMPORTANT: Add a sleep before daemon-reload to ensure all files are fully written
echo "Waiting for file operations to complete before reloading systemd..."
sleep 5

# Reload systemd, with retry logic
echo "Reloading systemd daemon..."
systemctl daemon-reload
if [ $? -ne 0 ]; then
  echo "First systemctl daemon-reload failed, retrying after 5 seconds..."
  sleep 5
  systemctl daemon-reload
fi

# Wait again before starting the service
echo "Waiting before starting the application service..."
sleep 5

# Restart the app service
echo "Starting application service..."
systemctl restart app.service

# Verify the service started correctly
echo "Verifying service status..."
sleep 10
SERVICE_STATUS=$(systemctl is-active app.service)
if [ "$SERVICE_STATUS" != "active" ]; then
  echo "WARNING: Service is not active after restart. Current status: $SERVICE_STATUS"
  echo "Attempting to fix and restart..."
  
  # Additional debugging and fixes
  echo "Checking service logs..."
  journalctl -u app.service --no-pager | tail -30 > /var/log/app-service-debug.log
  
  # Ensure log directory exists (again, just to be safe)
  mkdir -p /var/log/webapp
  chown csye6225:csye6225 /var/log/webapp
  
  # Reload and restart again
  systemctl daemon-reload
  systemctl restart app.service
  
  # Final check
  sleep 10
  FINAL_STATUS=$(systemctl is-active app.service)
  if [ "$FINAL_STATUS" != "active" ]; then
    echo "ERROR: Service failed to start after multiple attempts. Please check logs."
  else
    echo "Service successfully started after additional fixes."
  fi
else
  echo "Service started successfully!"
fi

echo "User data script completed at $(date)"
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebApp-ASG-Instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

###########################
# Auto Scaling Group
###########################
resource "aws_autoscaling_group" "app_asg" {
  name             = "webapp-asg"
  min_size         = 3
  max_size         = 5
  desired_capacity = 3
  default_cooldown = 60
  vpc_zone_identifier = [
    for subnet_key, subnet in aws_subnet.public :
    subnet.id if contains(split("-", subnet_key), local.primary_vpc_key)
  ]

  # Ensure load balancer, launch template and RDS are created first
  depends_on = [
    aws_launch_template.app_launch_template,
    aws_db_instance.csye6225,
    null_resource.wait_for_db,
    aws_lb.app_lb,
    aws_lb_target_group.app_tg,
    aws_lb_listener.http,
    aws_lb_listener.https
  ]

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "WebApp-ASG-Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.env
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

###########################
# Auto Scaling Policies
###########################
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = var.cooldown_period
  policy_type            = "SimpleScaling"

  depends_on = [aws_autoscaling_group.app_asg]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.cooldown_period
  policy_type            = "SimpleScaling"

  depends_on = [aws_autoscaling_group.app_asg]
}

###########################
# CloudWatch Alarms for Auto Scaling
###########################
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_up_threshold
  alarm_description   = "Scale up when CPU exceeds ${var.scale_up_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }

  depends_on = [aws_autoscaling_policy.scale_up]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_down_threshold
  alarm_description   = "Scale down when CPU is below ${var.scale_down_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }

  depends_on = [aws_autoscaling_policy.scale_down]
}