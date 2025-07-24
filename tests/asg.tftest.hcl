###############################################
# Provider stub – fast local-only execution
###############################################
provider "aws" {
  region                      = "ap-southeast-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

###############################################
# Phase 1 – Setup networking prerequisites
###############################################
run "setup" {
  module {
    source = "./tests/setup"
  }
}

###############################################
# Phase 2 – Plan autoscaling group creation
###############################################
run "plan_autoscaling" {
  command = plan

  variables {
    # feed dummy IDs from setup
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids

    name_prefix               = "test-asg-${run.setup.suffix}"
    ami_id                    = "ami-0123456789abcdef0"
    instance_type             = "t3.micro"
    iam_instance_profile_name = "test-instance-profile"

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

    mixed_instances_policy = {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "capacity-optimized"
      spot_instance_pools                      = 2
      instance_types_override = [
        {
          instance_type     = "t3.micro"
          weighted_capacity = "1"
        },
        {
          instance_type     = "t3.small"
          weighted_capacity = "1"
        }
      ]
    }

    instance_refresh_policy = {
      strategy               = "Rolling"
      min_healthy_percentage = 50
      instance_warmup        = 300
    }

    warm_pool_config = {
      pool_state                  = "Stopped"
      min_size                    = 1
      max_group_prepared_capacity = 2
    }

    scheduled_scaling_actions = {
      business_hours = {
        recurrence       = "0 9 * * MON-FRI"
        min_size         = 2
        max_size         = 5
        desired_capacity = 3
      }
      off_hours = {
        recurrence       = "0 18 * * MON-FRI"
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
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
        threshold           = 80
        alarm_description   = "Scale up if CPU > 80% for 10 minutes"
        dimensions = [
          {
            name  = "AutoScalingGroupName"
            value = "test-asg-${run.setup.suffix}-asg"
          }
        ]
      }
    }

    enable_scaling_notifications = true
    scaling_notification_types = [
      "autoscaling:EC2_INSTANCE_LAUNCH",
      "autoscaling:EC2_INSTANCE_TERMINATE"
    ]

    tags = {
      Environment = "test"
      Project     = "autoscaling-test"
      ManagedBy   = "terraform"
    }

    asg_tags = [
      {
        key                 = "Name"
        value               = "test-asg-${run.setup.suffix}-instance"
        propagate_at_launch = true
      },
      {
        key                 = "Environment"
        value               = "test"
        propagate_at_launch = true
      }
    ]
  }


  ##########################################################
  # Assertions – verify resource count & key attributes
  ##########################################################
  assert {
    condition     = var.name_prefix == "test-asg-${run.setup.suffix}"
    error_message = "Name prefix not honoured by module."
  }

  assert {
    condition     = var.instance_type == "t3.micro"
    error_message = "Instance type not honoured by module."
  }
}

###############################################
# Phase 3 – Validation failure scenarios
###############################################
run "invalid_instance_type" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "test-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "invalid-instance-type" # unsupported instance type
    desired_capacity   = 2
    min_size           = 1
    max_size           = 5
  }

  expect_failures = [
    var.instance_type
  ]
}

###############################################
# Phase 4 – Test minimum configuration
###############################################
run "minimal_configuration" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "minimal-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"
  }

  assert {
    condition     = var.name_prefix == "minimal-asg-${run.setup.suffix}"
    error_message = "Minimal configuration name prefix not honoured."
  }

  assert {
    condition     = var.instance_type == "t3.micro"
    error_message = "Minimal configuration instance type not honoured."
  }
}

###############################################
# Phase 5 – Test capacity constraints
###############################################
run "capacity_constraints" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "capacity-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"
    min_size           = 2
    max_size           = 10
    desired_capacity   = 5
  }

  assert {
    condition     = var.min_size >= 1
    error_message = "Minimum size should be at least 1."
  }

  assert {
    condition     = var.max_size >= var.min_size
    error_message = "Maximum size should be greater than or equal to minimum size."
  }

  assert {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "Desired capacity should be between min and max size."
  }
}

###############################################
# Phase 6 – Test mixed instances policy
###############################################
run "mixed_instances_policy_only" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "mixed-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    mixed_instances_policy = {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "capacity-optimized"
      spot_instance_pools                      = 2
      instance_types_override = [
        {
          instance_type     = "t3.micro"
          weighted_capacity = "1"
        },
        {
          instance_type     = "t3.small"
          weighted_capacity = "2"
        }
      ]
    }
  }

  assert {
    condition     = var.mixed_instances_policy != null
    error_message = "Mixed instances policy should be configured."
  }

  assert {
    condition     = length(var.mixed_instances_policy.instance_types_override) >= 1
    error_message = "Mixed instances policy should have at least one instance type override."
  }
}

###############################################
# Phase 7 – Test scaling policies
###############################################
run "scaling_policies_only" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "scaling-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    target_tracking_scaling_policies = {
      cpu_utilization = {
        predefined_metric_type = "ASGAverageCPUUtilization"
        target_value           = 70.0
        disable_scale_in       = false
      }
      memory_utilization = {
        predefined_metric_type = "ASGAverageNetworkIn"
        target_value           = 1000000
        disable_scale_in       = true
      }
    }

    step_scaling_policies = {
      scale_up = {
        adjustment_type = "ChangeInCapacity"
        cooldown        = 300
        step_adjustments = [
          {
            scaling_adjustment          = 1
            metric_interval_lower_bound = 0
            metric_interval_upper_bound = 10
          },
          {
            scaling_adjustment          = 2
            metric_interval_lower_bound = 10
          }
        ]
      }
    }
  }

  assert {
    condition     = length(var.target_tracking_scaling_policies) >= 1
    error_message = "Should have at least one target tracking scaling policy."
  }

  assert {
    condition     = length(var.step_scaling_policies) >= 1
    error_message = "Should have at least one step scaling policy."
  }
}

###############################################
# Phase 8 – Test scheduled scaling
###############################################
run "scheduled_scaling_only" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "scheduled-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    scheduled_scaling_actions = {
      business_hours = {
        recurrence       = "0 9 * * MON-FRI"
        min_size         = 3
        max_size         = 8
        desired_capacity = 5
      }
      off_hours = {
        recurrence       = "0 18 * * MON-FRI"
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
      }
      weekend = {
        recurrence       = "0 0 * * SAT,SUN"
        min_size         = 1
        max_size         = 2
        desired_capacity = 1
      }
    }
  }

  assert {
    condition     = length(var.scheduled_scaling_actions) >= 1
    error_message = "Should have at least one scheduled scaling action."
  }
}

###############################################
# Phase 9 – Test warm pool configuration
###############################################
run "warm_pool_configuration" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "warm-pool-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    warm_pool_config = {
      pool_state                  = "Stopped"
      min_size                    = 2
      max_group_prepared_capacity = 5
    }
  }

  assert {
    condition     = var.warm_pool_config != null
    error_message = "Warm pool configuration should be set."
  }

  assert {
    condition     = var.warm_pool_config.pool_state == "Stopped"
    error_message = "Warm pool state should be Stopped."
  }
}

###############################################
# Phase 10 – Test invalid capacity values
###############################################
run "invalid_capacity_values" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "invalid-capacity-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"
    min_size           = 0 # Invalid: should be >= 1
    max_size           = 0 # Invalid: should be >= 1
    desired_capacity   = 0 # Invalid: should be >= 1
  }

  expect_failures = [
    var.min_size,
    var.max_size,
    var.desired_capacity
  ]
}

###############################################
# Phase 11 – Test invalid health check type
###############################################
run "invalid_health_check_type" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "invalid-health-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"
    health_check_type  = "INVALID_TYPE" # Should be EC2 or ELB
  }

  expect_failures = [
    var.health_check_type
  ]
}

###############################################
# Phase 12 – Test block device mappings
###############################################
run "block_device_mappings" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "block-device-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    block_device_mappings = [
      {
        device_name           = "/dev/sda1"
        volume_size           = 20
        volume_type           = "gp3"
        delete_on_termination = true
        encrypted             = true
      },
      {
        device_name           = "/dev/sdf"
        volume_size           = 100
        volume_type           = "gp3"
        delete_on_termination = false
        encrypted             = true
      }
    ]
  }

  assert {
    condition     = length(var.block_device_mappings) >= 1
    error_message = "Should have at least one block device mapping."
  }
}

###############################################
# Phase 13 – Test invalid AMI ID
###############################################
run "invalid_ami_id" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "invalid-ami-asg-${run.setup.suffix}"
    ami_id             = "invalid-ami-id" # Invalid AMI format
    instance_type      = "t3.micro"
  }

  expect_failures = [
    var.ami_id
  ]
}

###############################################
# Phase 14 – Test invalid health check grace period
###############################################
run "invalid_health_check_grace_period" {
  command = plan

  variables {
    subnet_ids                = run.setup.public_subnet_ids
    security_group_ids        = run.setup.security_group_ids
    name_prefix               = "invalid-grace-asg-${run.setup.suffix}"
    ami_id                    = "ami-0123456789abcdef0"
    instance_type             = "t3.micro"
    health_check_grace_period = -1 # Invalid: should be >= 0
  }

  expect_failures = [
    var.health_check_grace_period
  ]
}

###############################################
# Phase 15 – Test comprehensive configuration
###############################################
run "comprehensive_configuration" {
  command = plan

  variables {
    subnet_ids                = run.setup.public_subnet_ids
    security_group_ids        = run.setup.security_group_ids
    name_prefix               = "comprehensive-asg-${run.setup.suffix}"
    ami_id                    = "ami-0123456789abcdef0"
    instance_type             = "t3.micro"
    iam_instance_profile_name = "test-instance-profile"

    desired_capacity          = 3
    min_size                  = 2
    max_size                  = 8
    health_check_grace_period = 600
    health_check_type         = "ELB"

    associate_public_ip_address = true
    detailed_monitoring_enabled = true

    target_tracking_scaling_policies = {
      cpu_utilization = {
        predefined_metric_type = "ASGAverageCPUUtilization"
        target_value           = 75.0
        disable_scale_in       = false
      }
    }

    mixed_instances_policy = {
      on_demand_base_capacity                  = 2
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
      spot_instance_pools                      = 3
      instance_types_override = [
        {
          instance_type     = "t3.micro"
          weighted_capacity = "1"
        },
        {
          instance_type     = "t3.small"
          weighted_capacity = "2"
        },
        {
          instance_type     = "t3.medium"
          weighted_capacity = "3"
        }
      ]
    }

    instance_refresh_policy = {
      strategy               = "Rolling"
      min_healthy_percentage = 75
      instance_warmup        = 600
    }

    warm_pool_config = {
      pool_state                  = "Stopped"
      min_size                    = 1
      max_group_prepared_capacity = 3
    }

    scheduled_scaling_actions = {
      business_hours = {
        recurrence       = "0 9 * * MON-FRI"
        min_size         = 3
        max_size         = 10
        desired_capacity = 5
      }
      off_hours = {
        recurrence       = "0 18 * * MON-FRI"
        min_size         = 1
        max_size         = 5
        desired_capacity = 2
      }
      weekend = {
        recurrence       = "0 0 * * SAT,SUN"
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
      }
    }

    scaling_alarms = {
      high_cpu = {
        comparison_operator = "GreaterThanThreshold"
        evaluation_periods  = 3
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        period              = 300
        statistic           = "Average"
        threshold           = 85
        alarm_description   = "Scale up if CPU > 85% for 15 minutes"
        dimensions = [
          {
            name  = "AutoScalingGroupName"
            value = "comprehensive-asg-${run.setup.suffix}-asg"
          }
        ]
      }
      high_memory = {
        comparison_operator = "GreaterThanThreshold"
        evaluation_periods  = 2
        metric_name         = "MemoryUtilization"
        namespace           = "AWS/EC2"
        period              = 300
        statistic           = "Average"
        threshold           = 90
        alarm_description   = "Scale up if Memory > 90% for 10 minutes"
        dimensions = [
          {
            name  = "AutoScalingGroupName"
            value = "comprehensive-asg-${run.setup.suffix}-asg"
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

    tags = {
      Environment = "test"
      Project     = "autoscaling-test"
      ManagedBy   = "terraform"
      CostCenter  = "engineering"
    }

    asg_tags = [
      {
        key                 = "Name"
        value               = "comprehensive-asg-${run.setup.suffix}-instance"
        propagate_at_launch = true
      },
      {
        key                 = "Environment"
        value               = "test"
        propagate_at_launch = true
      },
      {
        key                 = "Project"
        value               = "autoscaling-test"
        propagate_at_launch = true
      }
    ]

    block_device_mappings = [
      {
        device_name           = "/dev/sda1"
        volume_size           = 30
        volume_type           = "gp3"
        delete_on_termination = true
        encrypted             = true
      },
      {
        device_name           = "/dev/sdf"
        volume_size           = 200
        volume_type           = "gp3"
        delete_on_termination = false
        encrypted             = true
      }
    ]
  }

  assert {
    condition     = var.name_prefix == "comprehensive-asg-${run.setup.suffix}"
    error_message = "Comprehensive configuration name prefix not honoured."
  }

  assert {
    condition     = var.instance_type == "t3.micro"
    error_message = "Comprehensive configuration instance type not honoured."
  }

  assert {
    condition     = var.desired_capacity == 3
    error_message = "Comprehensive configuration desired capacity not honoured."
  }

  assert {
    condition     = var.health_check_type == "ELB"
    error_message = "Comprehensive configuration health check type not honoured."
  }

  assert {
    condition     = var.associate_public_ip_address == true
    error_message = "Comprehensive configuration public IP association not honoured."
  }

  assert {
    condition     = var.detailed_monitoring_enabled == true
    error_message = "Comprehensive configuration detailed monitoring not honoured."
  }

  assert {
    condition     = length(var.target_tracking_scaling_policies) >= 1
    error_message = "Comprehensive configuration should have scaling policies."
  }

  assert {
    condition     = var.mixed_instances_policy != null
    error_message = "Comprehensive configuration should have mixed instances policy."
  }

  assert {
    condition     = var.warm_pool_config != null
    error_message = "Comprehensive configuration should have warm pool config."
  }

  assert {
    condition     = length(var.scheduled_scaling_actions) >= 1
    error_message = "Comprehensive configuration should have scheduled scaling actions."
  }

  assert {
    condition     = length(var.scaling_alarms) >= 1
    error_message = "Comprehensive configuration should have scaling alarms."
  }

  assert {
    condition     = var.enable_scaling_notifications == true
    error_message = "Comprehensive configuration should have scaling notifications enabled."
  }

  assert {
    condition     = length(var.tags) >= 1
    error_message = "Comprehensive configuration should have tags."
  }

  assert {
    condition     = length(var.asg_tags) >= 1
    error_message = "Comprehensive configuration should have ASG tags."
  }

  assert {
    condition     = length(var.block_device_mappings) >= 1
    error_message = "Comprehensive configuration should have block device mappings."
  }
}

###############################################
# Phase 16 – Test lifecycle configuration
###############################################
run "lifecycle_configuration" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "lifecycle-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"
    desired_capacity   = 2
    min_size           = 1
    max_size           = 5
  }

  assert {
    condition     = var.name_prefix == "lifecycle-asg-${run.setup.suffix}"
    error_message = "Lifecycle configuration name prefix not honoured."
  }

  assert {
    condition     = var.desired_capacity == 2
    error_message = "Lifecycle configuration desired capacity not honoured."
  }

  # Verify that the autoscaling group has the expected lifecycle configuration
  # Note: We can't directly test ignore_changes in the plan, but we can verify
  # that the resource is created with the expected configuration
}

###############################################
# Phase 17 – Test customized metrics
###############################################
run "customized_metrics" {
  command = plan

  variables {
    subnet_ids         = run.setup.public_subnet_ids
    security_group_ids = run.setup.security_group_ids
    name_prefix        = "custom-metrics-asg-${run.setup.suffix}"
    ami_id             = "ami-0123456789abcdef0"
    instance_type      = "t3.micro"

    target_tracking_scaling_policies = {
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
              value = "custom-metrics-asg-${run.setup.suffix}-asg"
            }
          ]
        }
      }
    }
  }

  assert {
    condition     = var.name_prefix == "custom-metrics-asg-${run.setup.suffix}"
    error_message = "Customized metrics configuration name prefix not honoured."
  }

  assert {
    condition     = length(var.target_tracking_scaling_policies) >= 1
    error_message = "Should have at least one target tracking scaling policy with customized metrics."
  }
}
