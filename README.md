# Microservices E-commerce Application - AWS Learner Lab Deployment Guide

A complete e-commerce application with microservices architecture, deployed on AWS using Terraform, Docker, and Kubernetes.

## Architecture Overview

- **Frontend**: React application with Material-UI
- **Backend Services**:
  - User Service (Authentication & User Management)
  - Product Service (Product Catalog & Inventory)
  - Order Service (Order Processing & Payments)
- **Infrastructure**: AWS EKS (Kubernetes)
- **CI/CD**: Jenkins
- **Monitoring**: Prometheus & Grafana
- **Logging**: AWS CloudWatch

## Prerequisites

1. **AWS Learner Lab Access**:
   - Active AWS Learner Lab account
   - AWS CLI installed locally
   - AWS credentials from Learner Lab configured

2. **Local Development Tools**:
   - Node.js v18+
   - Docker Desktop
   - kubectl
   - Terraform v1.0+
   - Git

## Detailed Setup Instructions

### 1. AWS Learner Lab Configuration

```bash
# 1. Start your AWS Learner Lab session

# 2. Click on 'AWS Details' and copy your credentials

# 3. Configure AWS CLI
aws configure
AWS Access Key ID: [Your Learner Lab Access Key]
AWS Secret Access Key: [Your Learner Lab Secret Key]
Default region name: us-east-1
Default output format: json

# 4. Verify AWS configuration
aws sts get-caller-identity
```

### 2. Clone and Configure Repository

```bash
# Clone the repository
git clone [your-repo-url]
cd microservices

# Install dependencies for all services
cd services/user-service && npm install
cd ../product-service && npm install
cd ../order-service && npm install
cd ../../frontend && npm install
```

### 3. Infrastructure Setup

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars
cat << EOF > terraform.tfvars
aws_region = "us-east-1"
project_name = "ecommerce"
environment = "dev"
database_username = "admin"
database_password = "your-secure-password"
vpc_cidr = "10.0.0.0/16"
EOF

# Apply Terraform configuration
terraform apply
```

### 4. Database Setup

```bash
# Get RDS endpoint from Terraform output
export DB_HOST=$(terraform output -raw rds_endpoint)

# Initialize database schema
cd ../services/user-service
npx sequelize-cli db:migrate
cd ../product-service
npx sequelize-cli db:migrate
cd ../order-service
npx sequelize-cli db:migrate
```

### 5. Deploy Microservices

```bash
# Build Docker images
docker build -t user-service ./services/user-service
docker build -t product-service ./services/product-service
docker build -t order-service ./services/order-service

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag user-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/user-service:latest
docker tag product-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/product-service:latest
docker tag order-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/order-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/user-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/product-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/order-service:latest
```

### 6. Deploy Frontend

```bash
# Build frontend
cd frontend
npm run build

# Deploy to S3
aws s3 sync build/ s3://your-bucket-name
```

### 7. Configure Kubernetes

```bash
# Update kubeconfig
aws eks update-kubeconfig --name ecommerce-cluster --region us-east-1

# Apply Kubernetes configurations
kubectl apply -f k8s/
```

### 8. Set Up Monitoring

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus

# Install Grafana
helm install grafana grafana/grafana

# Get Grafana admin password
kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## Environment Variables

Create a `.env` file in each service directory:

### User Service
```env
NODE_ENV=production
PORT=3001
DB_HOST=your-rds-endpoint
DB_USER=admin
DB_PASSWORD=your-password
DB_NAME=ecommerce
JWT_SECRET=your-jwt-secret
```

### Product Service
```env
NODE_ENV=production
PORT=3002
DB_HOST=your-rds-endpoint
DB_USER=admin
DB_PASSWORD=your-password
DB_NAME=ecommerce
AWS_S3_BUCKET=your-bucket-name
```

### Order Service
```env
NODE_ENV=production
PORT=3003
DB_HOST=your-rds-endpoint
DB_USER=admin
DB_PASSWORD=your-password
DB_NAME=ecommerce
STRIPE_SECRET_KEY=your-stripe-key
```

### Frontend
```env
REACT_APP_API_URL=your-api-gateway-url
REACT_APP_STRIPE_PUBLIC_KEY=your-stripe-public-key
```

## Accessing the Application

After deployment, you can access the services at:

- Frontend: `http://your-s3-bucket-url`
- API Gateway: `https://your-api-gateway-url`
- Grafana: `http://your-grafana-loadbalancer:3000`
- Prometheus: `http://your-prometheus-server:9090`

## Common Issues and Solutions

1. **AWS Learner Lab Session Expired**:
   - Start a new lab session
   - Update AWS credentials
   - Run `aws configure` again

2. **Database Connection Issues**:
   - Check security group rules
   - Verify RDS endpoint
   - Test connection using `psql`

3. **EKS Connection Issues**:
   - Update kubeconfig
   - Check IAM roles
   - Verify VPC networking

4. **Image Push Failures**:
   - Refresh ECR login
   - Check repository permissions
   - Verify image tags

## Cleanup

To avoid unnecessary AWS charges:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete Helm releases
helm uninstall prometheus
helm uninstall grafana

# Destroy infrastructure
cd terraform
terraform destroy

# Empty S3 bucket
aws s3 rm s3://your-bucket-name --recursive
```

## Security Best Practices

1. **AWS IAM**:
   - Use least privilege principle
   - Rotate access keys regularly
   - Enable MFA for AWS accounts

2. **Kubernetes**:
   - Keep EKS version updated
   - Use network policies
   - Enable audit logging

3. **Application**:
   - Store secrets in AWS Secrets Manager
   - Enable HTTPS/TLS
   - Implement rate limiting

## Monitoring and Logging

1. **CloudWatch**:
   - Set up log groups for each service
   - Create alarms for critical metrics
   - Configure dashboard for monitoring

2. **Grafana**:
   - Import recommended dashboards
   - Set up alerting
   - Configure user authentication

3. **Prometheus**:
   - Configure service discovery
   - Set up alerting rules
   - Monitor cluster metrics

## Support and Troubleshooting

For issues:
1. Check CloudWatch logs
2. Verify security group rules
3. Test connectivity between services
4. Check Kubernetes pod logs
5. Verify AWS resource limits

For additional help, contact: [your-contact-info]
