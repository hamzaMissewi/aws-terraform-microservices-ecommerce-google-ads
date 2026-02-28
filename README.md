# 🛒 Microservices E-Commerce Platform with Google Ads Integration

A production-ready, scalable microservices e-commerce platform built with Terraform and AWS, featuring advanced **Google Ads integration** with Go-based Lambda functions for automated campaign optimization and real-time analytics.

## 🏗️ Architecture Overview

### **Microservices Components**
- **API Gateway**: Amazon API Gateway with custom domain
- **User Service**: Go with DynamoDB (NEW)
- **Product Service**: Python with DocumentDB
- **Order Service**: Java with MySQL
- **Payment Service**: Node.js with Redis
- **Notification Service**: Python with SQS
- **Google Ads Integration**: Go Lambda functions (NEW)

### **Infrastructure Components**
- **Container Orchestration**: Amazon ECS with Fargate
- **Databases**: RDS (PostgreSQL, MySQL), DocumentDB (MongoDB), DynamoDB
- **Caching**: ElastiCache Redis
- **Messaging**: SQS, SNS
- **CDN**: CloudFront with WAF
- **Monitoring**: CloudWatch, X-Ray, Container Insights
- **CI/CD**: GitHub Actions with CodePipeline
- **Google Ads**: Automated campaign monitoring and bid optimization

### **Network Architecture**
- **VPC**: Multi-AZ with public/private subnets
- **Load Balancing**: Application Load Balancers
- **Security**: Security Groups, WAF, Secrets Manager
- **DNS**: Route53 with ACM certificates

## 🚀 New Features

### **Google Ads Integration** 🎯
- **Automated Campaign Monitoring**: Real-time performance tracking with intelligent alerting
- **AI-Powered Bid Optimization**: Go-based Lambda functions for smart bid adjustments
- **Performance Analytics**: Comprehensive analytics with historical data storage
- **Scheduled Workflows**: Event-driven architecture for continuous optimization

### **Go Microservices** 🐹
- **High-Performance Services**: Go-based user service with DynamoDB
- **Docker Optimized**: Multi-stage builds with security best practices
- **Cloud Native**: Designed for serverless and containerized deployments

### **Advanced Security** 🔒
- **Zero Trust Architecture**: Comprehensive security controls
- **Secrets Management**: AWS Secrets Manager integration
- **Compliance Ready**: GDPR and SOC 2 considerations
- **Network Security**: VPC endpoints and private connectivity

## 📊 Google Ads Integration

### **Core Features**
- **Campaign Monitor Lambda**: Monitors performance every 15 minutes
- **Bid Optimizer Lambda**: Optimizes bids hourly based on performance metrics
- **Ad Analytics Lambda**: Stores and analyzes performance data

### **Smart Optimization**
- **Performance-Based Bidding**: Adjusts bids based on CTR, conversion rate, and cost
- **Automated Alerts**: Notifies about low performance or high costs
- **ROI Maximization**: Focuses on campaigns with best return on investment

### **Integration Architecture**
```
Google Ads API → Go Lambda Functions → AWS SNS → Notifications
                    ↓
              AWS Secrets Manager (Credentials)
                    ↓
              DynamoDB (Analytics Storage)
```

## 🚀 Features

### **High Availability**
- Multi-AZ deployment across 3 availability zones
- Auto Scaling Groups with health checks
- Database replication and failover
- Container service discovery

### **Security**
- VPC with private subnets for databases
- Secrets Manager for credential management
- WAF rules for common attacks
- IAM roles with least privilege
- Encrypted data in transit and at rest

### **Scalability**
- Auto Scaling based on CPU/memory metrics
- Container orchestration with ECS Fargate
- CDN for static content delivery
- Read replicas for database scaling

### **Monitoring & Observability**
- CloudWatch dashboards and alerts
- X-Ray distributed tracing
- Container Insights
- Custom metrics and logs
- Health checks and alerting

## 📊 Cost Optimization

### **Free Tier Utilization**
- **EC2**: t3.micro instances for development
- **RDS**: db.t3.micro with 20GB storage
- **S3**: Standard storage (first 5GB free)
- **CloudFront**: First 1TB data transfer free
- **Lambda**: 1M requests/month free

### **Estimated Monthly Costs**
- **Development**: ~$50-80/month
- **Production**: ~$200-500/month
- **High Traffic**: ~$1000-2000/month

## 🛠️ Technology Stack

### **Infrastructure as Code**
- **Terraform**: v1.15.0+
- **AWS Provider**: v5.0+
- **Modules**: Reusable Terraform modules

### **Container Platform**
- **Amazon ECS**: Fargate launch type
- **Docker**: Container images
- **ECR**: Container registry

### **Databases**
- **Amazon RDS**: PostgreSQL, MySQL
- **Amazon DocumentDB**: MongoDB compatible
- **Amazon ElastiCache**: Redis

### **CI/CD**
- **GitHub Actions**: Build and deploy pipelines
- **AWS CodePipeline**: Deployment automation
- **AWS CodeBuild**: Container building

## 📁 Project Structure

```
microservices-ecommerce/
├── README.md                    # This file
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── versions.tf                  # Provider versions
├── terraform.tfvars.example     # Example variables file
├── dev.tfvars                   # Development environment
├── prod.tfvars                  # Production environment
├── backend.tf                   # S3 backend configuration
├── .gitignore                   # Git ignore file
├── scripts/                     # Deployment and utility scripts
│   ├── deploy.sh               # Deployment script
│   ├── destroy.sh              # Cleanup script
│   └── init.sh                 # Initialization script
├── modules/                     # Reusable Terraform modules
│   ├── vpc/                    # VPC and networking
│   ├── ecs/                    # ECS cluster and services
│   ├── databases/              # Database configurations
│   ├── monitoring/             # CloudWatch and alerts
│   ├── security/               # Security groups and IAM
│   └── ci-cd/                  # CI/CD pipeline
├── services/                    # Microservice definitions
│   ├── user-service/           # User management service
│   ├── product-service/        # Product catalog service
│   ├── order-service/          # Order processing service
│   ├── payment-service/        # Payment processing service
│   └── notification-service/   # Notification service
├── docker/                      # Docker configurations
│   ├── Dockerfile.user         # User service Dockerfile
│   ├── Dockerfile.product      # Product service Dockerfile
│   └── Dockerfile.order        # Order service Dockerfile
└── github-actions/               # GitHub Actions workflows
    ├── build-and-deploy.yml    # Main CI/CD pipeline
    ├── security-scan.yml       # Security scanning
    └── performance-test.yml     # Performance testing
```

## 🚀 Quick Start

### **Prerequisites**
- Terraform v1.15.0+
- AWS CLI v2 configured
- Docker installed
- GitHub account (for CI/CD)

### **1. Clone and Initialize**
```bash
git clone <repository-url>
cd microservices-ecommerce
./scripts/init.sh
```

### **2. Configure Variables**
```bash
cp terraform.tfvars.example dev.tfvars
# Edit dev.tfvars with your configuration
```

### **3. Deploy Infrastructure**
```bash
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### **4. Deploy Services**
```bash
./scripts/deploy.sh dev
```

## 🔧 Configuration

### **Environment Variables**
```bash
# AWS Configuration
export AWS_REGION="us-east-1"
export AWS_PROFILE="default"

# Terraform Configuration
export TF_VAR_environment="dev"
export TF_VAR_project_name="ecommerce-platform"
```

### **Customization**
- Modify `variables.tf` for project-specific settings
- Update service configurations in `services/` directory
- Adjust scaling parameters in `modules/ecs/`
- Configure monitoring thresholds in `modules/monitoring/`

## 📈 Monitoring

### **CloudWatch Dashboards**
- Service performance metrics
- Database performance
- Auto Scaling events
- Error rates and latency

### **Alerting**
- High CPU/memory utilization
- Database connection issues
- Service health checks
- Security events

## 🔒 Security Features

- **Network Security**: VPC, security groups, NACLs
- **Data Encryption**: KMS-managed encryption keys
- **Secrets Management**: AWS Secrets Manager
- **Access Control**: IAM roles and policies
- **Web Security**: AWS WAF rules
- **Compliance**: SOC 2, GDPR considerations

## 🧪 Testing

### **Infrastructure Testing**
```bash
# Validate Terraform configuration
terraform validate

# Security scanning
checkov -d .

# Cost estimation
infracost breakdown --path .
```

### **Application Testing**
```bash
# Load testing
k6 run tests/load-test.js

# Security scanning
npm audit

# Performance testing
artillery run tests/performance-test.yml
```

## 📚 Learning Outcomes

This project demonstrates:
- **Microservices Architecture**: Service design and communication
- **Container Orchestration**: ECS Fargate deployment patterns
- **Infrastructure as Code**: Terraform best practices
- **CI/CD Pipelines**: Automated deployment workflows
- **Monitoring & Observability**: Comprehensive monitoring setup
- **Security Implementation**: Defense-in-depth security model
- **Cost Optimization**: Resource management and cost controls
- **Scalability Design**: Auto Scaling and load balancing

## 🎯 Portfolio Value

### **Technical Skills Demonstrated**
- Advanced Terraform with modules and workspaces
- AWS services integration and configuration
- Microservices architecture design
- DevOps and CI/CD implementation
- Security best practices
- Cost optimization strategies

### **Real-World Applications**
- Production-ready infrastructure
- Enterprise-level architecture patterns
- Scalable and maintainable code
- Comprehensive documentation
- Automated deployment and monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For questions or support:
- Create an issue in the repository
- Check the documentation in the `docs/` folder
- Review the troubleshooting guide

---

**⭐ Star this repository if it helps you learn or build your portfolio!**
