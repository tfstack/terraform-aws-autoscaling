# Performance Focused Example

This example demonstrates high-performance autoscaling with detailed monitoring, custom metrics, and advanced scaling policies. It's designed for applications that require maximum performance and detailed observability.

## Features

- **High-performance instances**: Uses compute-optimized instances (c5 series)
- **Custom metrics**: Application-level monitoring with custom CloudWatch metrics
- **Multiple scaling policies**: CPU, network, and custom metric-based scaling
- **Detailed monitoring**: 1-minute granularity for precise monitoring
- **Advanced scaling**: Both target tracking and step scaling policies
- **Load balancer integration**: Application Load Balancer for traffic distribution
- **Mixed instances policy**: 70% on-demand, 30% spot instances for cost optimization

## Configuration

### Autoscaling Group

- **Instance Types**: `c5.large`, `c5.xlarge`, `c5.2xlarge`, `c5.4xlarge`
- **Capacity**: 2-15 instances (desired: 3)
- **Availability Zones**: 3 AZs for performance and reliability
- **Detailed Monitoring**: 1-minute granularity enabled

### Mixed Instances Policy

```hcl
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
```

### Target Tracking Scaling Policies

```hcl
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
    target_value           = 1000
    disable_scale_in       = false
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
```

### Step Scaling Policies

```hcl
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
```

**Note**: Step scaling policies use non-overlapping intervals to comply with AWS requirements.

### Monitoring

```hcl
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
  }
  high_memory = {
    # Memory utilization monitoring
  }
  high_latency = {
    # Application latency monitoring
  }
  low_performance = {
    # Performance degradation monitoring
  }
}
```

## Usage

1. **Initialize the example**:

   ```bash
   cd examples/performance-focused
   terraform init
   ```

2. **Review the plan**:

   ```bash
   terraform plan
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply
   ```

4. **Clean up**:

   ```bash
   terraform destroy
   ```

## What's Created

- VPC with public and private subnets across 3 AZs
- Application Load Balancer with target group
- Security group for the autoscaling group
- IAM role and instance profile
- Auto Scaling Group with mixed instances policy (70% on-demand, 30% spot)
- Multiple target tracking and step scaling policies
- CloudWatch alarms for comprehensive monitoring
- SNS notifications for scaling events
- Instance refresh policy for rolling updates

## Use Cases

This example is ideal for:

- **High-traffic applications**: Websites with variable load
- **API services**: REST APIs with performance requirements
- **Data processing**: Batch and real-time processing workloads
- **Gaming servers**: Game servers with dynamic player counts
- **Media streaming**: Video and audio streaming services

## Performance Features

### High-Performance Instances

- **Compute-optimized**: c5 series for maximum CPU performance
- **Multiple sizes**: Scales from c5.large to c5.4xlarge
- **Weighted capacity**: Larger instances have higher weight

### Advanced Scaling

- **Multiple metrics**: CPU, network, and custom application metrics
- **Target tracking**: Maintains optimal performance levels
- **Step scaling**: Handles sudden load spikes
- **Custom metrics**: Application-specific scaling criteria

### Detailed Monitoring

- **1-minute granularity**: Precise performance monitoring
- **Custom metrics**: Application-level monitoring
- **Multiple alarms**: Comprehensive alerting
- **Performance tracking**: Latency and throughput monitoring

### Load Balancer Integration

- **Health checks**: Ensures only healthy instances serve traffic
- **SSL termination**: HTTPS support for secure connections
- **Traffic distribution**: Even load distribution across instances

## Customization

To customize this example:

1. **Adjust instance types**: Modify `instance_types_override` for different workloads
2. **Change scaling thresholds**: Update target values based on application needs
3. **Add custom metrics**: Include application-specific CloudWatch metrics
4. **Modify monitoring**: Adjust alarm thresholds and evaluation periods
5. **Scale capacity**: Modify min/max/desired capacity

## Best Practices

1. **Performance testing**: Test scaling policies under load
2. **Monitoring**: Set up comprehensive performance monitoring
3. **Custom metrics**: Implement application-specific metrics
4. **Capacity planning**: Right-size instances for workload
5. **Cost optimization**: Balance performance vs. cost
6. **AWS compliance**: Ensure step scaling intervals are non-overlapping
7. **Spot instance management**: Monitor spot interruptions and plan accordingly

## Cost Considerations

- **Compute-optimized instances**: Higher costs for performance
- **Detailed monitoring**: Additional CloudWatch costs
- **Custom metrics**: Costs for custom metric storage
- **Load balancer**: ALB costs for traffic distribution
- **Spot instances**: Cost savings with some risk

## Performance Optimization

- **Instance sizing**: Choose appropriate instance types
- **Scaling thresholds**: Fine-tune based on application behavior
- **Cooldown periods**: Prevent scaling oscillations
- **Health checks**: Balance responsiveness vs. overhead
- **Custom metrics**: Use application-specific scaling criteria

## Common AWS Step Scaling Issues

### ⚠️ **Overlapping Intervals**

**Problem**: AWS step scaling policies require non-overlapping metric intervals.

**Example of Invalid Configuration:**

```hcl
step_adjustments = [
  {
    scaling_adjustment          = -1
    metric_interval_upper_bound = -10  # -∞ to -10
  },
  {
    scaling_adjustment          = -2
    metric_interval_lower_bound = -20
    metric_interval_upper_bound = -10  # -20 to -10 (OVERLAP!)
  }
]
```

**Solution**: Ensure intervals are non-overlapping:

```hcl
step_adjustments = [
  {
    scaling_adjustment          = -1
    metric_interval_upper_bound = -11  # -∞ to -11
  },
  {
    scaling_adjustment          = -2
    metric_interval_lower_bound = -11  # -11 to -10
    metric_interval_upper_bound = -10
  }
]
```

### ⚠️ **Missing Null Lower Bound**

**Problem**: When using negative lower bounds, AWS requires at least one step with no lower bound (null).

**Solution**: Always include a step with only `metric_interval_upper_bound` when using negative bounds.

### ⚠️ **Cooldown Parameter**

**Problem**: `cooldown` parameter is only supported for `SimpleScaling` policy type, not `StepScaling`.

**Solution**: Remove `cooldown` from step scaling policies. Use target tracking policies for automatic cooldown management.

### ⚠️ **Warm Pools with Spot Instances**

**Problem**: Warm pools cannot be used with mixed instances policies that include spot instances.

**Solution**: Either remove warm pools or use only on-demand instances in mixed instances policies.

### ⚠️ **Spot Instance Allocation Strategy**

**Problem**: `spot_instance_pools` only works with `lowest-price` allocation strategy.

**Solution**: Use `lowest-price` when specifying `spot_instance_pools`, or use `capacity-optimized` without pools.

### ⚠️ **Target Tracking Conflicts**

**Problem**: Cannot specify both `predefined_metric_specification` and `customized_metric_specification` in the same policy.

**Solution**: Use conditional blocks to include only one specification type per policy.

## Troubleshooting Checklist

- [ ] Step scaling intervals are non-overlapping
- [ ] At least one step has no lower bound when using negative bounds
- [ ] No `cooldown` parameter in step scaling policies
- [ ] Warm pools not used with spot instances
- [ ] Correct spot allocation strategy for instance pools
- [ ] Only one metric specification type per target tracking policy
