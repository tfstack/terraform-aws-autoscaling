# Launch Template Outputs
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.this.id
}

output "launch_template_name" {
  description = "Name of the launch template"
  value       = aws_launch_template.this.name
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.this.arn
}

# Auto Scaling Group Outputs
output "autoscaling_group_id" {
  description = "ID of the auto scaling group"
  value       = aws_autoscaling_group.this.id
}

output "autoscaling_group_name" {
  description = "Name of the auto scaling group"
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the auto scaling group"
  value       = aws_autoscaling_group.this.arn
}

output "autoscaling_group_desired_capacity" {
  description = "Desired capacity of the auto scaling group"
  value       = aws_autoscaling_group.this.desired_capacity
}

output "autoscaling_group_min_size" {
  description = "Minimum size of the auto scaling group"
  value       = aws_autoscaling_group.this.min_size
}

output "autoscaling_group_max_size" {
  description = "Maximum size of the auto scaling group"
  value       = aws_autoscaling_group.this.max_size
}

# Scaling Policy Outputs
output "target_tracking_policy_arns" {
  description = "ARNs of target tracking scaling policies"
  value       = length(var.target_tracking_scaling_policies) > 0 ? { for k, v in aws_autoscaling_policy.target_tracking : k => v.arn } : {}
}

output "step_scaling_policy_arns" {
  description = "ARNs of step scaling policies"
  value       = length(var.step_scaling_policies) > 0 ? { for k, v in aws_autoscaling_policy.step_scaling : k => v.arn } : {}
}

# CloudWatch Alarm Outputs
output "scaling_alarm_arns" {
  description = "ARNs of CloudWatch scaling alarms"
  value       = length(var.scaling_alarms) > 0 ? { for k, v in aws_cloudwatch_metric_alarm.scaling_alarms : k => v.arn } : {}
}

# SNS Topic Outputs
output "scaling_notifications_topic_arn" {
  description = "ARN of the SNS topic for scaling notifications"
  value       = var.enable_scaling_notifications ? aws_sns_topic.scaling_notifications[0].arn : null
}

# Instance Information
output "availability_zones" {
  description = "List of availability zones used by the auto scaling group"
  value       = aws_autoscaling_group.this.availability_zones
}

# Mixed Instances Policy Outputs
output "mixed_instances_policy_id" {
  description = "ID of the mixed instances policy"
  value       = var.mixed_instances_policy != null ? aws_autoscaling_group.this.mixed_instances_policy[0].launch_template[0].launch_template_specification[0].launch_template_id : null
}

# Warm Pool Outputs
output "warm_pool_size" {
  description = "Size of the warm pool"
  value       = var.warm_pool_config != null ? var.warm_pool_config.min_size : null
}
