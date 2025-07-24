# Simple Scaling Example

This example demonstrates a basic CPU-based autoscaling configuration with a single instance type. It's perfect for getting started with the autoscaling module or for simple applications that don't require complex scaling strategies.

## Features

- **Basic CPU-based scaling**: Uses target tracking scaling policy based on CPU utilization
- **Single instance type**: Uses `t3.micro` instances for simplicity
- **Simple networking**: Basic VPC with public and private subnets
- **Health checks**: ELB health checks for reliable instance management
- **IAM integration**: Proper IAM roles and instance profiles

## Configuration

### Autoscaling Group

- **Instance Type**: `t3.micro`
- **Capacity**: 1-5 instances (desired: 2)
- **Health Check**: 300-second grace period
- **Scaling Policy**: CPU utilization target of 70%

### Networking

- **VPC**: Custom VPC with 2 availability zones
- **Subnets**: Public and private subnets in each AZ
- **Security Groups**: Basic rules for SSH (22) and HTTP (80)

### Scaling Policies

```hcl
target_tracking_scaling_policies = {
  cpu_utilization = {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70.0
    disable_scale_in       = false
  }
}
```

## Usage

1. **Initialize the example**:

   ```bash
   cd examples/simple-scaling
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

- VPC with public and private subnets
- Security group for the autoscaling group
- IAM role and instance profile
- Auto Scaling Group with launch template
- Target tracking scaling policy
- CloudWatch alarms for monitoring

## Use Cases

This example is ideal for:

- **Development environments**: Simple, cost-effective scaling
- **Basic web applications**: Standard CPU-based scaling
- **Learning and testing**: Easy to understand and modify
- **Proof of concepts**: Quick setup for demonstrating autoscaling

## Customization

To customize this example:

1. **Change instance type**: Modify `instance_type` in the module configuration
2. **Adjust scaling thresholds**: Update `target_value` in the scaling policy
3. **Modify capacity**: Change `min_size`, `max_size`, and `desired_capacity`
4. **Add more scaling policies**: Include additional target tracking or step scaling policies

## Cost Considerations

- Uses on-demand instances only (no spot instances)
- Minimal monitoring costs
- Suitable for development and testing workloads
