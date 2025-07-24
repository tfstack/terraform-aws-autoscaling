# Cost Optimized Example
# This example demonstrates cost optimization with spot instances, warm pools, and predictive scaling

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  name = "cost-opt-app"
  tags = {
    Environment  = "dev"
    Project      = "cost-opt-app"
    ManagedBy    = "terraform"
    CostCenter   = "engineering"
    Optimization = "cost"
  }
}

# Data sources for dynamic AMI reference
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC and networking resources
module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name = local.name
  vpc_cidr = "10.0.0.0/16"

  availability_zones   = ["ap-southeast-2a", "ap-southeast-2b"]
  public_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  private_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  tags = local.tags
}

# Security group for the autoscaling group
resource "aws_security_group" "test" {
  name_prefix = "${local.name}-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-security-group"
  })
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${local.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

module "cost_optimized_autoscaling" {
  source = "../../"

  name_prefix   = local.name
  ami_id        = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.small"

  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [aws_security_group.test.id]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name

  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 8
  health_check_grace_period = 300

  mixed_instances_policy = {
    on_demand_base_capacity                  = 0
    on_demand_percentage_above_base_capacity = 20 # 80% spot instances
    spot_allocation_strategy                 = "lowest-price"
    spot_instance_pools                      = 4
    instance_types_override = [
      {
        instance_type     = "t3.small"
        weighted_capacity = "1"
      },
      {
        instance_type     = "t3.medium"
        weighted_capacity = "1"
      },
      {
        instance_type     = "c5.large"
        weighted_capacity = "2"
      },
      {
        instance_type     = "c5.xlarge"
        weighted_capacity = "3"
      }
    ]
  }

  instance_refresh_policy = {
    strategy               = "Rolling"
    min_healthy_percentage = 50
    instance_warmup        = 300
  }

  target_tracking_scaling_policies = {
    cpu_utilization = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 60.0 # Lower threshold for cost optimization
      disable_scale_in       = false
    }
    network_in = {
      predefined_metric_type = "ASGAverageNetworkIn"
      target_value           = 800000 # 800 KB/s
      disable_scale_in       = false
    }
  }

  scheduled_scaling_actions = {
    business_hours = {
      recurrence       = "0 9 * * MON-FRI" # 9 AM on weekdays
      min_size         = 3
      max_size         = 8
      desired_capacity = 4
    }
    off_hours = {
      recurrence       = "0 18 * * MON-FRI" # 6 PM on weekdays
      min_size         = 1
      max_size         = 4
      desired_capacity = 2
    }
    weekend = {
      recurrence       = "0 0 * * SAT" # Midnight on Saturday
      min_size         = 1
      max_size         = 3
      desired_capacity = 1
    }
  }

  scaling_alarms = {
    cost_alert = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 1
      metric_name         = "EstimatedCharges"
      namespace           = "AWS/Billing"
      period              = 86400 # Daily
      statistic           = "Maximum"
      threshold           = 50 # Alert if daily cost > $50
      alarm_description   = "Alert when daily cost exceeds threshold"
      dimensions = [
        {
          name  = "Currency"
          value = "USD"
        }
      ]
    }
    spot_interruption = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 1
      metric_name         = "SpotInstanceInterruption"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Sum"
      threshold           = 0
      alarm_description   = "Alert when spot instances are interrupted"
      dimensions = [
        {
          name  = "AutoScalingGroupName"
          value = "${local.name}-asg"
        }
      ]
    }
  }

  enable_scaling_notifications = true
  scaling_notification_types = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]

  tags = local.tags

  asg_tags = [
    {
      key                 = "Name"
      value               = "${local.name}-instance"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "CostCenter"
      value               = "engineering"
      propagate_at_launch = true
    },
    {
      key                 = "Optimization"
      value               = "cost"
      propagate_at_launch = true
    }
  ]
}
