# Google Ads Integration with Terraform and Go

This document describes the Google Ads integration module that provides automated campaign monitoring, bid optimization, and performance analytics using Go Lambda functions.

## 🎯 Overview

The Google Ads integration module provides:
- **Campaign Monitoring**: Real-time performance tracking and alerting
- **Bid Optimization**: AI-powered bid adjustments based on performance metrics
- **Performance Analytics**: Comprehensive analytics and reporting
- **Automated Workflows**: Scheduled tasks for continuous optimization

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Google Ads    │───▶│  Go Lambda       │───▶│   AWS SNS       │
│     API         │    │  Functions       │    │   Notifications │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  AWS Secrets     │
                       │  Manager         │
                       └──────────────────┘
```

## 🚀 Features

### Campaign Monitoring
- Real-time performance tracking
- Automated alerting for:
  - Low CTR campaigns
  - High cost with no conversions
  - High CPC keywords
- Customizable thresholds and rules

### Bid Optimization
- Performance-based bid adjustments
- Multi-factor optimization:
  - Click-through rate (CTR)
  - Conversion rate
  - Cost per conversion
  - Return on ad spend (ROAS)
- Automated bid recommendations

### Performance Analytics
- Historical performance tracking
- Trend analysis
- ROI calculations
- Custom dashboards

## 📋 Prerequisites

1. **Google Ads API Access**
   - Developer token
   - OAuth 2.0 credentials
   - Refresh token

2. **AWS Permissions**
   - Lambda execution role
   - Secrets Manager access
   - SNS publishing permissions

## 🔧 Configuration

### 1. Google Ads Setup

```bash
# Create Google Ads API credentials
# 1. Go to Google Cloud Console
# 2. Enable Google Ads API
# 3. Create OAuth 2.0 credentials
# 4. Generate refresh token
# 5. Apply for developer token
```

### 2. Terraform Variables

```hcl
# terraform.tfvars
google_ads_client_id      = "your_client_id"
google_ads_client_secret  = "your_client_secret"
google_ads_refresh_token  = "your_refresh_token"
google_ads_developer_token = "your_developer_token"

campaign_monitor_schedule = "rate(15 minutes)"
bid_optimizer_schedule     = "rate(1 hour)"
optimization_interval     = "60"
```

### 3. Environment Variables

```bash
# For Lambda functions
GOOGLE_ADS_CUSTOMER_ID = "1234567890"
GOOGLE_ADS_SECRET_ARN   = "arn:aws:secretsmanager:..."
SNS_TOPIC_ARN          = "arn:aws:sns:..."
ENVIRONMENT            = "production"
```

## 📊 Lambda Functions

### Campaign Monitor (`campaign-monitor`)

**Purpose**: Monitor campaign performance and generate alerts

**Triggers**: 
- Scheduled (every 15 minutes by default)
- Manual invocation

**Alert Types**:
- `LOW_PERFORMANCE`: CTR < 0.5%
- `HIGH_COST_NO_CONVERSIONS`: Cost > $100 with 0 conversions
- `HIGH_CPC`: CPC > $5.00

**Example Alert**:
```json
{
  "campaign_id": "123456789",
  "campaign_name": "Summer Sale 2024",
  "alert_type": "LOW_PERFORMANCE",
  "message": "Campaign 'Summer Sale 2024' has low CTR: 0.35%",
  "ctr": 0.0035,
  "cost": 45.67,
  "conversions": 2
}
```

### Bid Optimizer (`bid-optimizer`)

**Purpose**: Optimize bids based on performance metrics

**Triggers**:
- Scheduled (every 1 hour by default)
- Manual invocation

**Optimization Strategies**:
- **Increase Bid**: High CTR (>2%) and conversion rate (>5%)
- **Decrease Bid**: Low CTR (<0.5%) or high cost per conversion (>$100)
- **Moderate Increase**: Good performance with growth potential

**Example Recommendation**:
```json
{
  "campaign_id": "123456789",
  "keyword_text": "buy shoes online",
  "current_bid": 2.50,
  "recommended_bid": 3.125,
  "optimization_type": "INCREASE_BID",
  "reason": "High CTR (2.8%) and conversion rate (6.2%) with low cost per conversion ($25.40)",
  "expected_impact": "Estimated 25% increase in clicks and conversions"
}
```

### Ad Analytics (`ad-analytics`)

**Purpose**: Store and analyze performance data

**Features**:
- Historical data storage in DynamoDB
- Performance trend analysis
- ROI calculations
- Custom reporting

## 🔒 Security

### Secrets Management
- All Google Ads credentials stored in AWS Secrets Manager
- KMS encryption for sensitive data
- IAM role-based access control

### Network Security
- VPC endpoints for AWS services
- Security groups restricting access
- No public internet exposure

### Compliance
- GDPR-compliant data handling
- SOC 2 controls
- Audit logging

## 📈 Monitoring

### CloudWatch Metrics
- Lambda function invocations
- Execution duration
- Error rates
- Custom business metrics

### Alarms
- Function failures
- High execution times
- API quota exceeded

### Dashboards
- Campaign performance overview
- Bid optimization impact
- Cost analysis

## 🧪 Testing

### Local Development
```bash
# Build Lambda functions
cd lambda/campaign-monitor
go mod tidy
go build -o main main.go

# Test locally
sam local invoke CampaignMonitorFunction -e event.json
```

### Integration Testing
```bash
# Deploy test environment
terraform apply -var-file="test.tfvars"

# Run integration tests
go test ./tests/...
```

## 📚 API Reference

### Google Ads API Endpoints Used
- `SearchGoogleAdsStream`: Campaign and keyword data
- `MutateGoogleAds`: Bid updates
- `GetCustomer`: Account information

### AWS Services Used
- **Lambda**: Serverless compute
- **Secrets Manager**: Credential storage
- **SNS**: Notification delivery
- **CloudWatch**: Monitoring and logging
- **DynamoDB**: Analytics data storage
- **EventBridge**: Scheduled triggers

## 🚀 Deployment

### 1. Initialize Terraform
```bash
terraform init
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"
```

### 2. Deploy Lambda Functions
```bash
# Build and package functions
./scripts/build-lambda.sh

# Deploy via Terraform
terraform apply
```

### 3. Configure Monitoring
```bash
# Set up CloudWatch dashboards
./scripts/setup-monitoring.sh
```

## 🔧 Troubleshooting

### Common Issues

**1. Authentication Errors**
```
Error: "INVALID_ARGUMENT: Invalid OAuth 2.0 credentials"
Solution: Verify refresh token and client credentials
```

**2. Rate Limiting**
```
Error: "RESOURCE_EXHAUSTED: Rate limit exceeded"
Solution: Implement exponential backoff and reduce request frequency
```

**3. Lambda Timeouts**
```
Error: "Task timed out after 300.0 seconds"
Solution: Increase timeout or optimize query performance
```

### Debugging

**Enable Debug Logging**:
```bash
# Set environment variable
LOG_LEVEL=debug
```

**CloudWatch Logs**:
```bash
# View function logs
aws logs tail /aws/lambda/your-function-name --follow
```

## 📖 Best Practices

1. **Credential Rotation**: Rotate Google Ads credentials regularly
2. **Rate Limiting**: Implement proper rate limiting for API calls
3. **Error Handling**: Implement comprehensive error handling and retries
4. **Monitoring**: Set up comprehensive monitoring and alerting
5. **Testing**: Test thoroughly in non-production environments

## 🔄 Version Updates

### Lambda Function Updates
```bash
# Update function code
aws lambda update-function-code \
  --function-name campaign-monitor \
  --zip-file fileb://campaign-monitor.zip
```

### Terraform Updates
```bash
# Update infrastructure
terraform plan
terraform apply
```

## 📞 Support

For issues and questions:
1. Check CloudWatch logs for error details
2. Verify Google Ads API credentials
3. Review Terraform configuration
4. Check AWS service limits

---

**Note**: This integration requires proper Google Ads API access and AWS permissions. Ensure all prerequisites are met before deployment.
