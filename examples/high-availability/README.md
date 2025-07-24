# High Availability Example

This example demonstrates a high-availability autoscaling configuration with multi-AZ deployment, load balancer integration, and advanced health monitoring. It's designed for production workloads that require maximum uptime and reliability.

## Features

- **Multi-AZ deployment**: Spreads instances across 3 availability zones
- **Load balancer integration**: Application Load Balancer for traffic distribution
- **Mixed instances policy**: Combination of on-demand and spot instances
- **Advanced health checks**: ELB health checks with proper grace periods
- **Comprehensive monitoring**: Multiple CloudWatch alarms and SNS notifications
- **Step scaling policies**: Granular scaling based on performance metrics

## Configuration

### Autoscaling Group

- **Instance Types**: `t3.small`, `t3.medium`, `c5.large`
- **Capacity**: 2-10 instances (desired: 3)
- **Availability Zones**: 3 AZs for maximum redundancy
- **Health Check**: ELB health checks with 300-second grace period

### Load Balancer

- **Type**: Application Load Balancer
- **Target Group**: Health checks on port 80
- **Listener**: HTTP traffic on port 80
- **Security**: HTTPS support configured

### Mixed Instances Policy

```hcl
mixed_instances_policy = {
  on_demand_base_capacity                  = 1
  on_demand_percentage_above_base_capacity = 50
  spot_allocation_strategy                 = "lowest-price"
  spot_instance_pools                      = 3
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
    }
  ]
}
```

### Scaling Policies

- **Target Tracking**: CPU utilization (70%) and network utilization
- **Step Scaling**: Granular scaling based on performance metrics
- **Cooldown Periods**: Prevents rapid scaling oscillations

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
    threshold           = 80
    alarm_description   = "Scale up if CPU > 80% for 10 minutes"
  }
}
```

## Usage

1. **Initialize the example**:

   ```bash
   cd examples/high-availability
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
- Auto Scaling Group with mixed instances policy
- Target tracking and step scaling policies
- CloudWatch alarms for comprehensive monitoring
- SNS notifications for scaling events

## Use Cases

This example is ideal for:

- **Production applications**: High availability requirements
- **E-commerce platforms**: Cannot afford downtime
- **Business-critical systems**: Maximum reliability needed
- **Multi-region deployments**: Foundation for global scaling

## High Availability Features

### Multi-AZ Deployment

- **3 Availability Zones**: Maximum redundancy
- **Auto-recovery**: Automatic instance replacement
- **Load distribution**: Traffic spread across AZs

### Load Balancer Integration

- **Health checks**: Ensures only healthy instances receive traffic
- **SSL termination**: HTTPS support for secure connections
- **Session affinity**: Optional sticky sessions

### Advanced Monitoring

- **Multiple metrics**: CPU, memory, network monitoring
- **Step scaling**: Precise scaling based on performance
- **Alerts**: Immediate notification of issues

### Instance Management

- **Rolling updates**: Zero-downtime deployments
- **Instance refresh**: Automatic instance replacement
- **Health monitoring**: Continuous health assessment

## Customization

To customize this example:

1. **Adjust AZ count**: Modify availability zones in VPC configuration
2. **Change instance types**: Update `instance_types_override`
3. **Modify scaling thresholds**: Update target values and alarm thresholds
4. **Add SSL certificates**: Configure HTTPS listeners
5. **Adjust capacity**: Modify min/max/desired capacity

## Best Practices

1. **Health checks**: Use application-level health checks
2. **Monitoring**: Set up comprehensive monitoring and alerting
3. **Backup strategies**: Implement proper backup and disaster recovery
4. **Security**: Use security groups and IAM roles properly
5. **Testing**: Regularly test failover scenarios

## Cost Considerations

- **Multi-AZ**: Higher costs for redundancy
- **Load balancer**: Additional costs for ALB
- **Monitoring**: CloudWatch costs for detailed monitoring
- **Spot instances**: Cost savings with some risk
- **Data transfer**: Inter-AZ traffic costs

## Performance Optimization

- **Instance types**: Choose appropriate instance types for workload
- **Scaling policies**: Fine-tune scaling thresholds
- **Cooldown periods**: Prevent scaling oscillations
- **Health check intervals**: Balance responsiveness vs. overhead
