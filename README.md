# terraform-aws-autoscaling

Terraform module for managing AWS Auto Scaling groups and launch templates

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_notification.scaling_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_notification) | resource |
| [aws_autoscaling_policy.step_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_autoscaling_policy.target_tracking](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_autoscaling_schedule.scheduled_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_cloudwatch_metric_alarm.scaling_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_sns_topic.scaling_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID for the launch template | `string` | n/a | yes |
| <a name="input_asg_tags"></a> [asg\_tags](#input\_asg\_tags) | Tags for the auto scaling group | <pre>list(object({<br/>    key                 = string<br/>    value               = string<br/>    propagate_at_launch = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to associate public IP address | `bool` | `false` | no |
| <a name="input_block_device_mappings"></a> [block\_device\_mappings](#input\_block\_device\_mappings) | Block device mappings for the launch template | <pre>list(object({<br/>    device_name           = string<br/>    volume_size           = number<br/>    volume_type           = string<br/>    delete_on_termination = bool<br/>    encrypted             = bool<br/>    kms_key_id            = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Desired capacity of the auto scaling group | `number` | `1` | no |
| <a name="input_detailed_monitoring_enabled"></a> [detailed\_monitoring\_enabled](#input\_detailed\_monitoring\_enabled) | Whether to enable detailed monitoring | `bool` | `false` | no |
| <a name="input_enable_scaling_notifications"></a> [enable\_scaling\_notifications](#input\_enable\_scaling\_notifications) | Whether to enable scaling notifications | `bool` | `false` | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | Health check grace period in seconds | `number` | `300` | no |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | Health check type (EC2 or ELB) | `string` | `"EC2"` | no |
| <a name="input_iam_instance_profile_name"></a> [iam\_instance\_profile\_name](#input\_iam\_instance\_profile\_name) | IAM instance profile name | `string` | `null` | no |
| <a name="input_instance_refresh_policy"></a> [instance\_refresh\_policy](#input\_instance\_refresh\_policy) | Instance refresh policy configuration | <pre>object({<br/>    strategy               = string<br/>    min_healthy_percentage = number<br/>    instance_warmup        = optional(number, 300)<br/>  })</pre> | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Instance type for the launch template | `string` | `"t3.micro"` | no |
| <a name="input_launch_template_name_prefix"></a> [launch\_template\_name\_prefix](#input\_launch\_template\_name\_prefix) | Prefix for launch template name | `string` | `"lt-"` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum size of the auto scaling group | `number` | `3` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum size of the auto scaling group | `number` | `1` | no |
| <a name="input_mixed_instances_policy"></a> [mixed\_instances\_policy](#input\_mixed\_instances\_policy) | Mixed instances policy configuration | <pre>object({<br/>    on_demand_base_capacity                  = optional(number, 0)<br/>    on_demand_percentage_above_base_capacity = optional(number, 100)<br/>    spot_allocation_strategy                 = optional(string, "lowest-price")<br/>    spot_instance_pools                      = optional(number, 2)<br/>    instance_types_override = list(object({<br/>      instance_type     = string<br/>      weighted_capacity = string<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_scaling_alarms"></a> [scaling\_alarms](#input\_scaling\_alarms) | CloudWatch alarms for scaling | <pre>map(object({<br/>    comparison_operator = string<br/>    evaluation_periods  = number<br/>    metric_name         = string<br/>    namespace           = string<br/>    period              = number<br/>    statistic           = string<br/>    threshold           = number<br/>    alarm_description   = optional(string)<br/>    alarm_actions       = optional(list(string))<br/>    ok_actions          = optional(list(string))<br/>    dimensions = list(object({<br/>      name  = string<br/>      value = string<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_scaling_notification_types"></a> [scaling\_notification\_types](#input\_scaling\_notification\_types) | Types of scaling notifications to send | `list(string)` | <pre>[<br/>  "autoscaling:EC2_INSTANCE_LAUNCH",<br/>  "autoscaling:EC2_INSTANCE_TERMINATE"<br/>]</pre> | no |
| <a name="input_scheduled_scaling_actions"></a> [scheduled\_scaling\_actions](#input\_scheduled\_scaling\_actions) | Scheduled scaling actions | <pre>map(object({<br/>    start_time       = optional(string)<br/>    end_time         = optional(string)<br/>    recurrence       = optional(string)<br/>    min_size         = optional(number)<br/>    max_size         = optional(number)<br/>    desired_capacity = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs | `list(string)` | `[]` | no |
| <a name="input_step_scaling_policies"></a> [step\_scaling\_policies](#input\_step\_scaling\_policies) | Step scaling policies | <pre>map(object({<br/>    adjustment_type = string<br/>    step_adjustments = list(object({<br/>      scaling_adjustment          = number<br/>      metric_interval_lower_bound = optional(number)<br/>      metric_interval_upper_bound = optional(number)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the auto scaling group | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_target_group_arns"></a> [target\_group\_arns](#input\_target\_group\_arns) | Target group ARNs | `list(string)` | `[]` | no |
| <a name="input_target_tracking_scaling_policies"></a> [target\_tracking\_scaling\_policies](#input\_target\_tracking\_scaling\_policies) | Target tracking scaling policies | <pre>map(object({<br/>    predefined_metric_type = optional(string)<br/>    resource_label         = optional(string)<br/>    target_value           = number<br/>    scale_in_cooldown      = optional(number)<br/>    scale_out_cooldown     = optional(number)<br/>    disable_scale_in       = optional(bool, false)<br/>    customized_metric_specification = optional(object({<br/>      metric_name = string<br/>      namespace   = string<br/>      statistic   = string<br/>      unit        = optional(string)<br/>      metric_dimensions = list(object({<br/>        name  = string<br/>        value = string<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data script for instances | `string` | `""` | no |
| <a name="input_warm_pool_config"></a> [warm\_pool\_config](#input\_warm\_pool\_config) | Warm pool configuration | <pre>object({<br/>    pool_state                  = string<br/>    min_size                    = number<br/>    max_group_prepared_capacity = optional(number)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | ARN of the auto scaling group |
| <a name="output_autoscaling_group_desired_capacity"></a> [autoscaling\_group\_desired\_capacity](#output\_autoscaling\_group\_desired\_capacity) | Desired capacity of the auto scaling group |
| <a name="output_autoscaling_group_id"></a> [autoscaling\_group\_id](#output\_autoscaling\_group\_id) | ID of the auto scaling group |
| <a name="output_autoscaling_group_max_size"></a> [autoscaling\_group\_max\_size](#output\_autoscaling\_group\_max\_size) | Maximum size of the auto scaling group |
| <a name="output_autoscaling_group_min_size"></a> [autoscaling\_group\_min\_size](#output\_autoscaling\_group\_min\_size) | Minimum size of the auto scaling group |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the auto scaling group |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | List of availability zones used by the auto scaling group |
| <a name="output_launch_template_arn"></a> [launch\_template\_arn](#output\_launch\_template\_arn) | ARN of the launch template |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template |
| <a name="output_launch_template_name"></a> [launch\_template\_name](#output\_launch\_template\_name) | Name of the launch template |
| <a name="output_mixed_instances_policy_id"></a> [mixed\_instances\_policy\_id](#output\_mixed\_instances\_policy\_id) | ID of the mixed instances policy |
| <a name="output_scaling_alarm_arns"></a> [scaling\_alarm\_arns](#output\_scaling\_alarm\_arns) | ARNs of CloudWatch scaling alarms |
| <a name="output_scaling_notifications_topic_arn"></a> [scaling\_notifications\_topic\_arn](#output\_scaling\_notifications\_topic\_arn) | ARN of the SNS topic for scaling notifications |
| <a name="output_step_scaling_policy_arns"></a> [step\_scaling\_policy\_arns](#output\_step\_scaling\_policy\_arns) | ARNs of step scaling policies |
| <a name="output_target_tracking_policy_arns"></a> [target\_tracking\_policy\_arns](#output\_target\_tracking\_policy\_arns) | ARNs of target tracking scaling policies |
| <a name="output_warm_pool_size"></a> [warm\_pool\_size](#output\_warm\_pool\_size) | Size of the warm pool |
<!-- END_TF_DOCS -->
