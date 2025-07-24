# Simple Scaling Example
# This example demonstrates basic CPU-based scaling with a single instance type

provider "aws" {
  region = "ap-southeast-2"
}

locals {
  name = "simple-app"
  tags = {
    Environment = "dev"
    Project     = "simple-app"
    ManagedBy   = "terraform"
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

module "simple_autoscaling" {
  source = "../../"

  name_prefix   = local.name
  ami_id        = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [aws_security_group.test.id]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name

  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 5
  health_check_grace_period = 300

  target_tracking_scaling_policies = {
    cpu_utilization = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70.0
      disable_scale_in       = false
    }
  }

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
    }
  ]
}
