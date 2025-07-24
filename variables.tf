# General Configuration
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Launch Template Configuration
variable "launch_template_name_prefix" {
  description = "Prefix for launch template name"
  type        = string
  default     = "lt-"
}

variable "ami_id" {
  description = "AMI ID for the launch template"
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "AMI ID must be a valid AWS AMI ID (e.g., ami-0123456789abcdef0)."
  }
}

variable "instance_type" {
  description = "Instance type for the launch template"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9]\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid AWS instance type (e.g., t3.micro, m5.large, c5.xlarge)."
  }
}

variable "user_data" {
  description = "User data script for instances"
  type        = string
  default     = ""
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
  default     = null
}

variable "block_device_mappings" {
  description = "Block device mappings for the launch template"
  type = list(object({
    device_name           = string
    volume_size           = number
    volume_type           = string
    delete_on_termination = bool
    encrypted             = bool
    kms_key_id            = optional(string)
  }))
  default = []
}

variable "associate_public_ip_address" {
  description = "Whether to associate public IP address"
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "Subnet IDs for the auto scaling group"
  type        = list(string)
}

variable "detailed_monitoring_enabled" {
  description = "Whether to enable detailed monitoring"
  type        = bool
  default     = false
}

# Auto Scaling Group Configuration
variable "desired_capacity" {
  description = "Desired capacity of the auto scaling group"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_capacity >= 1
    error_message = "Desired capacity must be at least 1."
  }
}

variable "max_size" {
  description = "Maximum size of the auto scaling group"
  type        = number
  default     = 3

  validation {
    condition     = var.max_size >= 1
    error_message = "Maximum size must be at least 1."
  }
}

variable "min_size" {
  description = "Minimum size of the auto scaling group"
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 1
    error_message = "Minimum size must be at least 1."
  }
}

variable "target_group_arns" {
  description = "Target group ARNs"
  type        = list(string)
  default     = []
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 300

  validation {
    condition     = var.health_check_grace_period >= 0
    error_message = "Health check grace period must be non-negative."
  }
}

variable "health_check_type" {
  description = "Health check type (EC2 or ELB)"
  type        = string
  default     = "EC2"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "Health check type must be either 'EC2' or 'ELB'."
  }
}

variable "asg_tags" {
  description = "Tags for the auto scaling group"
  type = list(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))
  default = []
}

# Mixed Instances Policy
variable "mixed_instances_policy" {
  description = "Mixed instances policy configuration"
  type = object({
    on_demand_base_capacity                  = optional(number, 0)
    on_demand_percentage_above_base_capacity = optional(number, 100)
    spot_allocation_strategy                 = optional(string, "lowest-price")
    spot_instance_pools                      = optional(number, 2)
    instance_types_override = list(object({
      instance_type     = string
      weighted_capacity = string
    }))
  })
  default = null
}

# Instance Refresh Policy
variable "instance_refresh_policy" {
  description = "Instance refresh policy configuration"
  type = object({
    strategy               = string
    min_healthy_percentage = number
    instance_warmup        = optional(number, 300)
  })
  default = null
}

# Warm Pool Configuration
variable "warm_pool_config" {
  description = "Warm pool configuration"
  type = object({
    pool_state                  = string
    min_size                    = number
    max_group_prepared_capacity = optional(number)
  })
  default = null
}

# Target Tracking Scaling Policies
variable "target_tracking_scaling_policies" {
  description = "Target tracking scaling policies"
  type = map(object({
    predefined_metric_type = optional(string)
    resource_label         = optional(string)
    target_value           = number
    scale_in_cooldown      = optional(number)
    scale_out_cooldown     = optional(number)
    disable_scale_in       = optional(bool, false)
    customized_metric_specification = optional(object({
      metric_name = string
      namespace   = string
      statistic   = string
      unit        = optional(string)
      metric_dimensions = list(object({
        name  = string
        value = string
      }))
    }))
  }))
  default = {}
}

# Step Scaling Policies
variable "step_scaling_policies" {
  description = "Step scaling policies"
  type = map(object({
    adjustment_type = string
    step_adjustments = list(object({
      scaling_adjustment          = number
      metric_interval_lower_bound = optional(number)
      metric_interval_upper_bound = optional(number)
    }))
  }))
  default = {}
}

# Scheduled Scaling Actions
variable "scheduled_scaling_actions" {
  description = "Scheduled scaling actions"
  type = map(object({
    start_time       = optional(string)
    end_time         = optional(string)
    recurrence       = optional(string)
    min_size         = optional(number)
    max_size         = optional(number)
    desired_capacity = optional(number)
  }))
  default = {}
}

# CloudWatch Alarms
variable "scaling_alarms" {
  description = "CloudWatch alarms for scaling"
  type = map(object({
    comparison_operator = string
    evaluation_periods  = number
    metric_name         = string
    namespace           = string
    period              = number
    statistic           = string
    threshold           = number
    alarm_description   = optional(string)
    alarm_actions       = optional(list(string))
    ok_actions          = optional(list(string))
    dimensions = list(object({
      name  = string
      value = string
    }))
  }))
  default = {}
}

# Scaling Notifications
variable "enable_scaling_notifications" {
  description = "Whether to enable scaling notifications"
  type        = bool
  default     = false
}

variable "scaling_notification_types" {
  description = "Types of scaling notifications to send"
  type        = list(string)
  default     = ["autoscaling:EC2_INSTANCE_LAUNCH", "autoscaling:EC2_INSTANCE_TERMINATE"]
}
