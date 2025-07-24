# Performance Focused Example
# This example demonstrates high-performance autoscaling with detailed monitoring and custom metrics

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  name = "perf-app"
  tags = {
    Environment = "prod"
    Project     = "perf-app"
    ManagedBy   = "terraform"
    Performance = "high"
    Monitoring  = "detailed"
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

  availability_zones   = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  public_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  private_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

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

  ingress {
    from_port   = 443
    to_port     = 443
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

# Application Load Balancer for health checks
resource "aws_lb" "test" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false

  tags = local.tags
}

# Target group for the ALB
resource "aws_lb_target_group" "test" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.tags
}

# ALB listener
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

module "performance_autoscaling" {
  source = "../../"

  name_prefix   = local.name
  ami_id        = data.aws_ami.amazon_linux_2.id
  instance_type = "c5.large"

  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [aws_security_group.test.id]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name

  desired_capacity          = 3
  min_size                  = 2
  max_size                  = 15
  health_check_grace_period = 300
  health_check_type         = "ELB"

  target_group_arns = [aws_lb_target_group.test.arn]

  detailed_monitoring_enabled = true

  mixed_instances_policy = {
    on_demand_base_capacity                  = 2
    on_demand_percentage_above_base_capacity = 70
    spot_allocation_strategy                 = "lowest-price"
    spot_instance_pools                      = 3
    instance_types_override = [
      {
        instance_type     = "c5.large"
        weighted_capacity = "1"
      },
      {
        instance_type     = "c5.xlarge"
        weighted_capacity = "2"
      },
      {
        instance_type     = "c5.2xlarge"
        weighted_capacity = "3"
      },
      {
        instance_type     = "c5.4xlarge"
        weighted_capacity = "4"
      }
    ]
  }

  instance_refresh_policy = {
    strategy               = "Rolling"
    min_healthy_percentage = 60
    instance_warmup        = 600 # Longer warmup for performance instances
  }

  target_tracking_scaling_policies = {
    cpu_utilization = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 75.0
      disable_scale_in       = false
    }
    network_in = {
      predefined_metric_type = "ASGAverageNetworkIn"
      target_value           = 2000000 # 2 MB/s
      disable_scale_in       = false
    }
    network_out = {
      predefined_metric_type = "ASGAverageNetworkOut"
      target_value           = 1500000 # 1.5 MB/s
      disable_scale_in       = false
    }
    custom_metric = {
      target_value     = 1000
      disable_scale_in = false
      customized_metric_specification = {
        metric_name = "ApplicationRequestsPerSecond"
        namespace   = "CustomMetrics"
        statistic   = "Average"
        metric_dimensions = [
          {
            name  = "AutoScalingGroupName"
            value = "${local.name}-asg"
          }
        ]
      }
    }
  }

  step_scaling_policies = {
    performance_scale_up = {
      adjustment_type = "ChangeInCapacity"
      step_adjustments = [
        {
          scaling_adjustment          = 1
          metric_interval_lower_bound = 0
          metric_interval_upper_bound = 10
        },
        {
          scaling_adjustment          = 2
          metric_interval_lower_bound = 10
          metric_interval_upper_bound = 20
        },
        {
          scaling_adjustment          = 3
          metric_interval_lower_bound = 20
          metric_interval_upper_bound = 30
        },
        {
          scaling_adjustment          = 5
          metric_interval_lower_bound = 30
        }
      ]
    }
    performance_scale_down = {
      adjustment_type = "ChangeInCapacity"
      step_adjustments = [
        {
          scaling_adjustment          = -1
          metric_interval_upper_bound = -11
        },
        {
          scaling_adjustment          = -2
          metric_interval_lower_bound = -11
          metric_interval_upper_bound = -10
        }
      ]
    }
  }

  scaling_alarms = {
    high_cpu = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 85
      alarm_description   = "Scale up if CPU > 85% for 10 minutes"
      dimensions = [
        {
          name  = "AutoScalingGroupName"
          value = "${local.name}-asg"
        }
      ]
    }
    high_memory = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "MemoryUtilization"
      namespace           = "CustomMetrics"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_description   = "Scale up if memory > 80% for 10 minutes"
      dimensions = [
        {
          name  = "AutoScalingGroupName"
          value = "${local.name}-asg"
        }
      ]
    }
    high_latency = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "ApplicationLatency"
      namespace           = "CustomMetrics"
      period              = 300
      statistic           = "Average"
      threshold           = 500 # 500ms
      alarm_description   = "Scale up if latency > 500ms for 10 minutes"
      dimensions = [
        {
          name  = "AutoScalingGroupName"
          value = "${local.name}-asg"
        }
      ]
    }
    low_performance = {
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 3
      metric_name         = "ApplicationRequestsPerSecond"
      namespace           = "CustomMetrics"
      period              = 300
      statistic           = "Average"
      threshold           = 100
      alarm_description   = "Scale down if requests < 100/s for 15 minutes"
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
      value               = "prod"
      propagate_at_launch = true
    },
    {
      key                 = "Performance"
      value               = "high"
      propagate_at_launch = true
    },
    {
      key                 = "Monitoring"
      value               = "detailed"
      propagate_at_launch = true
    }
  ]
}
