# Cost Optimized Example

This example demonstrates cost optimization strategies using spot instances, scheduled scaling, and predictive scaling policies. It's designed to minimize costs while maintaining application availability.

## Features

* **Mixed instances policy**: 80% spot instances, 20% on-demand for cost savings
* **Flexible scaling**: Automatically scales based on business hours
* **Multiple instance types**: Uses different instance types for flexibility
* **Cost monitoring**: CloudWatch alarms for cost tracking
* **Spot interruption handling**: Alarms for spot instance interruptions

## Configuration

### Autoscaling Group

* **Instance Types**: `t3.small`, `t3.medium`, `c5.large`, `c5.xlarge`
* **Capacity**: 1–8 instances (desired: 2)
* **Mixed Instances**: 80% spot instances, 20% on-demand
* **Spot Strategy**: `lowest-price` with 4 instance pools

### Scaling Schedules

Scaling is configured based on business hours to optimize cost:

```hcl
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
```

### Scaling Policies

* **CPU Utilization**: Target 60% (lower threshold for cost optimization)
* **Network In**: Target 800 KB/s
* **Cost Alerts**: Daily cost monitoring

### Cost Monitoring

```hcl
scaling_alarms = {
  cost_alert = {
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 1
    metric_name         = "EstimatedCharges"
    namespace           = "AWS/Billing"
    period              = 86400 # Daily
    statistic           = "Maximum"
    threshold           = 50 # Alert if daily cost > $50
  }
  spot_interruption = {
    # Monitors spot instance interruptions
  }
}
```

## Usage

1. **Initialize the example**:

   ```bash
   cd examples/cost-optimized
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

* VPC with public and private subnets
* Security group for the autoscaling group
* IAM role and instance profile
* Auto Scaling Group with mixed instances policy
* Target tracking scaling policies
* Time-based scaling logic
* CloudWatch alarms for cost and spot interruption monitoring
* SNS notifications for scaling events

## Use Cases

This example is ideal for:

* **Production workloads**: Cost-optimized with spot instances
* **Business applications**: Scales with usage patterns
* **Batch processing**: Can handle spot interruptions gracefully
* **Development environments**: Cost-conscious development teams

## Cost Optimization Strategies

### Spot Instances

* **80% spot instances**: Significant cost savings (up to 90% off)
* **Multiple instance types**: Better spot availability
* **Lowest-price strategy**: Maximizes cost savings

### Time-Based Scaling

* **Business hours**: Higher capacity during work hours
* **Off-hours**: Reduced capacity to save costs
* **Weekends**: Minimal capacity for maintenance

### Monitoring

* **Cost alerts**: Prevents unexpected charges
* **Spot interruptions**: Early warning for capacity planning
* **Performance monitoring**: Ensures quality isn't sacrificed

## Customization

To customize this example:

1. **Adjust spot percentage**: Modify `on_demand_percentage_above_base_capacity`
2. **Change instance types**: Update `instance_types_override`
3. **Modify scaling schedules**: Update `scheduled_scaling_actions`
4. **Adjust cost thresholds**: Update alarm thresholds

## Cost Considerations

* **Spot instances**: Up to 90% cost savings but with interruption risk
* **Time-based scaling**: Reduces costs during low-usage periods
* **Monitoring costs**: CloudWatch alarms and SNS notifications
* **Data transfer**: Consider costs for inter-AZ traffic

## Best Practices

1. **Test spot availability**: Ensure your instance types have good spot availability
2. **Monitor interruptions**: Set up alerts for spot interruptions
3. **Gradual scaling**: Use cooldown periods to prevent rapid scaling
4. **Cost monitoring**: Regularly review cost alerts and adjust thresholds
5. **Spot allocation strategy**: Use `lowest-price` when specifying `spot_instance_pools`
6. **Warm pools limitation**: Cannot use warm pools with mixed instances policies using spot instances
