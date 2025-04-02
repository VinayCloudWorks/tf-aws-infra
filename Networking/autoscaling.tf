###########################
# Launch Template
###########################
resource "aws_launch_template" "app_launch_template" {
  name          = "csye6225_asg"
  image_id      = data.aws_ami.webapp.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_role_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 25
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
# Export database configuration for the web application
echo "DB_HOST=${aws_db_instance.csye6225.address}" >> /etc/environment
echo "DB_USER=${var.db_username}" >> /etc/environment
echo "DB_PASSWORD=${var.db_password}" >> /etc/environment
echo "DB_NAME=${var.db_name}" >> /etc/environment
echo "DB_PORT=${var.db_port}" >> /etc/environment
# Export S3 bucket name for file storage
echo "S3_BUCKET_NAME=${aws_s3_bucket.attachments.bucket}" >> /etc/environment

# Create directories for CloudWatch agent
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo mkdir -p /var/log/webapp

# Install CloudWatch agent
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Create log directories with proper permissions
sudo touch /var/log/webapp/application.log
sudo touch /var/log/webapp/error.log
sudo chown csye6225:csye6225 /var/log/webapp/*
sudo chmod 664 /var/log/webapp/*

# Create CloudWatch agent configuration file
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/webapp/application.log",
            "log_group_name": "webapp-logs",
            "log_stream_name": "{instance_id}-application-log",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/webapp/error.log",
            "log_group_name": "webapp-logs",
            "log_stream_name": "{instance_id}-error-log",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "webapp-system-logs",
            "log_stream_name": "{instance_id}-syslog",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "WebApp",
    "metrics_collected": {
      "statsd": {
        "service_address": ":8125",
        "metrics_collection_interval": 10,
        "metrics_aggregation_interval": 60
      },
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["disk_used_percent"]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    }
  }
}
CWCONFIG

# Add the instance ID to environment for CloudWatch agent
EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "EC2_INSTANCE_ID=$EC2_INSTANCE_ID" >> /etc/opt/csye6225/env.conf

# Configure CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Create a custom environment file for the service using a different approach to avoid heredoc issues
sudo mkdir -p /etc/opt/csye6225
cat > /tmp/env.conf << 'ENDOFFILE'
DB_HOST=DB_HOST_VALUE
DB_USER=DB_USER_VALUE
DB_PASSWORD=DB_PASSWORD_VALUE
DB_PASS=DB_PASS_VALUE
MYSQL_PASSWORD=MYSQL_PASSWORD_VALUE
PASSWORD=PASSWORD_VALUE
DB_NAME=DB_NAME_VALUE
DB_PORT=DB_PORT_VALUE
S3_BUCKET_NAME=S3_BUCKET_VALUE
DB_DIALECT=mysql
PORT=3000
ENDOFFILE

# Replace placeholders with actual values
sed -i "s|DB_HOST_VALUE|${aws_db_instance.csye6225.address}|g" /tmp/env.conf
sed -i "s|DB_USER_VALUE|${var.db_username}|g" /tmp/env.conf
sed -i "s|DB_PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|DB_PASS_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|MYSQL_PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|PASSWORD_VALUE|${var.db_password}|g" /tmp/env.conf
sed -i "s|DB_NAME_VALUE|${var.db_name}|g" /tmp/env.conf
sed -i "s|DB_PORT_VALUE|${var.db_port}|g" /tmp/env.conf
sed -i "s|S3_BUCKET_VALUE|${aws_s3_bucket.attachments.bucket}|g" /tmp/env.conf

# Move the file to its final destination
sudo mv /tmp/env.conf /etc/opt/csye6225/env.conf

# Make sure the environment file is readable by the app user
sudo chmod 644 /etc/opt/csye6225/env.conf
sudo chown root:csye6225 /etc/opt/csye6225/env.conf || true

# Create systemd override directory
sudo mkdir -p /etc/systemd/system/app.service.d/

# Create systemd override file to use env.conf
cat > /tmp/override.conf << 'ENDOFCONF'
[Service]
EnvironmentFile=/etc/opt/csye6225/env.conf
ENDOFCONF
sudo mv /tmp/override.conf /etc/systemd/system/app.service.d/override.conf

# Fix deprecated syslog settings
sudo sed -i 's/StandardOutput=syslog/StandardOutput=journal/' /etc/systemd/system/app.service
sudo sed -i 's/StandardError=syslog/StandardError=journal/' /etc/systemd/system/app.service

# Log for debugging
echo "Setup completed at $(date)" > /var/log/app-setup.log
echo "RDS endpoint: ${aws_db_instance.csye6225.address}" >> /var/log/app-setup.log
cat /etc/opt/csye6225/env.conf >> /var/log/app-setup.log

# Reload systemd configuration and start the application service
sudo systemctl daemon-reload
sudo systemctl restart app.service
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
  name                = "webapp-asg"
  min_size            = 3
  max_size            = 5
  desired_capacity    = 3
  default_cooldown    = 60
  vpc_zone_identifier = values(aws_subnet.public)[*].id

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
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.cooldown_period
  policy_type            = "SimpleScaling"
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
}