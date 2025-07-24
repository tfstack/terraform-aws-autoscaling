# Launch Template
resource "aws_launch_template" "this" {
  name_prefix   = var.launch_template_name_prefix
  image_id      = var.ami_id
  instance_type = var.instance_type

  # User data
  user_data = base64encode(var.user_data)

  # IAM instance profile
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile_name != null ? [var.iam_instance_profile_name] : []
    content {
      name = iam_instance_profile.value
    }
  }

  # Block device mappings
  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size           = block_device_mappings.value.volume_size
        volume_type           = block_device_mappings.value.volume_type
        delete_on_termination = block_device_mappings.value.delete_on_termination
        encrypted             = block_device_mappings.value.encrypted
        kms_key_id            = block_device_mappings.value.kms_key_id
      }
    }
  }

  # Network interface configuration
  vpc_security_group_ids = var.security_group_ids

  # Monitoring
  monitoring {
    enabled = var.detailed_monitoring_enabled
  }

  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Tag specifications
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-instance" })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "this" {
  name                      = "${var.name_prefix}-asg"
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  target_group_arns         = var.target_group_arns
  vpc_zone_identifier       = var.subnet_ids
  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type

  # Launch template (only when not using mixed instances policy)
  dynamic "launch_template" {
    for_each = var.mixed_instances_policy == null ? [1] : []
    content {
      id      = aws_launch_template.this.id
      version = "$Latest"
    }
  }

  # Mixed instances policy
  dynamic "mixed_instances_policy" {
    for_each = var.mixed_instances_policy != null ? [var.mixed_instances_policy] : []
    content {
      instances_distribution {
        on_demand_base_capacity                  = mixed_instances_policy.value.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = mixed_instances_policy.value.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = mixed_instances_policy.value.spot_allocation_strategy
        spot_instance_pools                      = mixed_instances_policy.value.spot_instance_pools
      }

      launch_template {
        launch_template_specification {
          launch_template_id   = aws_launch_template.this.id
          launch_template_name = aws_launch_template.this.name
          version              = "$Latest"
        }

        dynamic "override" {
          for_each = mixed_instances_policy.value.instance_types_override
          content {
            instance_type     = override.value.instance_type
            weighted_capacity = override.value.weighted_capacity
          }
        }
      }
    }
  }

  # Instance refresh
  dynamic "instance_refresh" {
    for_each = var.instance_refresh_policy != null ? [var.instance_refresh_policy] : []
    content {
      strategy = instance_refresh.value.strategy
      preferences {
        min_healthy_percentage = instance_refresh.value.min_healthy_percentage
        instance_warmup        = instance_refresh.value.instance_warmup
      }
    }
  }

  # Warm pool
  dynamic "warm_pool" {
    for_each = var.warm_pool_config != null ? [var.warm_pool_config] : []
    content {
      pool_state                  = warm_pool.value.pool_state
      min_size                    = warm_pool.value.min_size
      max_group_prepared_capacity = warm_pool.value.max_group_prepared_capacity
    }
  }

  # Tags
  dynamic "tag" {
    for_each = var.asg_tags
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,  # Managed by autoscaling policies and scheduled actions
      target_group_arns, # May be updated by load balancer operations
    ]
  }
}

# Target Tracking Scaling Policies
resource "aws_autoscaling_policy" "target_tracking" {
  for_each = var.target_tracking_scaling_policies

  name                   = "${var.name_prefix}-target-tracking-${each.key}"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    dynamic "predefined_metric_specification" {
      for_each = each.value.predefined_metric_type != null ? [1] : []
      content {
        predefined_metric_type = each.value.predefined_metric_type
        resource_label         = lookup(each.value, "resource_label", null)
      }
    }

    target_value = each.value.target_value

    dynamic "customized_metric_specification" {
      for_each = each.value.customized_metric_specification != null ? [each.value.customized_metric_specification] : []
      content {
        metric_name = customized_metric_specification.value.metric_name
        namespace   = customized_metric_specification.value.namespace
        statistic   = customized_metric_specification.value.statistic
        unit        = lookup(customized_metric_specification.value, "unit", null)

        dynamic "metric_dimension" {
          for_each = customized_metric_specification.value.metric_dimensions
          content {
            name  = metric_dimension.value.name
            value = metric_dimension.value.value
          }
        }
      }
    }

    disable_scale_in = lookup(each.value, "disable_scale_in", false)
  }
}

# Step Scaling Policies
resource "aws_autoscaling_policy" "step_scaling" {
  for_each = var.step_scaling_policies

  name                   = "${var.name_prefix}-step-scaling-${each.key}"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "StepScaling"
  adjustment_type        = each.value.adjustment_type

  dynamic "step_adjustment" {
    for_each = each.value.step_adjustments
    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = lookup(step_adjustment.value, "metric_interval_lower_bound", null)
      metric_interval_upper_bound = lookup(step_adjustment.value, "metric_interval_upper_bound", null)
    }
  }
}

# Scheduled Scaling Actions
resource "aws_autoscaling_schedule" "scheduled_scaling" {
  for_each = var.scheduled_scaling_actions

  scheduled_action_name  = "${var.name_prefix}-scheduled-${each.key}"
  autoscaling_group_name = aws_autoscaling_group.this.name
  start_time             = lookup(each.value, "start_time", null)
  end_time               = lookup(each.value, "end_time", null)
  recurrence             = lookup(each.value, "recurrence", null)
  min_size               = lookup(each.value, "min_size", null)
  max_size               = lookup(each.value, "max_size", null)
  desired_capacity       = lookup(each.value, "desired_capacity", null)
}

# CloudWatch Alarms for Scaling
resource "aws_cloudwatch_metric_alarm" "scaling_alarms" {
  for_each = var.scaling_alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = lookup(each.value, "alarm_description", null)
  alarm_actions       = lookup(each.value, "alarm_actions", null)
  ok_actions          = lookup(each.value, "ok_actions", null)
}

# SNS Topic for Scaling Notifications
resource "aws_sns_topic" "scaling_notifications" {
  count = var.enable_scaling_notifications ? 1 : 0
  name  = "${var.name_prefix}-scaling-notifications"
  tags  = var.tags
}

# Auto Scaling Group Notification
resource "aws_autoscaling_notification" "scaling_notifications" {
  for_each = var.enable_scaling_notifications ? toset(var.scaling_notification_types) : []

  group_names = [aws_autoscaling_group.this.name]
  topic_arn   = aws_sns_topic.scaling_notifications[0].arn
  notifications = [
    each.value
  ]
}
