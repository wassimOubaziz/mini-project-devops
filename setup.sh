#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Starting setup process...${NC}"

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Configure AWS
echo "Please enter your AWS credentials:"
read -p "AWS Access Key ID: " aws_access_key
read -p "AWS Secret Access Key: " aws_secret_key
read -p "AWS Region (default: us-east-1): " aws_region
aws_region=${aws_region:-us-east-1}

# Configure AWS CLI
aws configure set aws_access_key_id $aws_access_key
aws configure set aws_secret_access_key $aws_secret_key
aws configure set region $aws_region
aws configure set output json

echo -e "${GREEN}AWS CLI configured successfully${NC}"

# Initialize Terraform
cd terraform
echo "Initializing Terraform..."
terraform init

# Create terraform.tfvars
echo "Creating terraform.tfvars..."
cat << EOF > terraform.tfvars
aws_region = "${aws_region}"
project_name = "microservices-demo"
environment = "dev"
database_username = "admin"
EOF

# Generate a random password for the database
DB_PASSWORD=$(openssl rand -base64 12)
echo "database_password = \"${DB_PASSWORD}\"" >> terraform.tfvars

# Apply Terraform configuration
echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Get EKS cluster name
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $aws_region

# Install Helm charts
echo "Installing Helm charts..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus -f ../k8s/prometheus-config.yaml

# Install Grafana
echo "Installing Grafana..."
helm install grafana grafana/grafana -f ../k8s/grafana-datasource.yaml

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Get Jenkins instance details
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
JENKINS_PASSWORD=$(terraform output -raw jenkins_initial_password)

# Print setup information
echo -e "\n${GREEN}Setup completed successfully!${NC}"
echo -e "\nImportant Information:"
echo -e "Database Password: ${DB_PASSWORD}"
echo -e "Grafana Admin Password: ${GRAFANA_PASSWORD}"
echo -e "Jenkins URL: http://${JENKINS_IP}:8080"
echo -e "Jenkins Initial Admin Password: ${JENKINS_PASSWORD}"
echo -e "\nNext steps:"
echo "1. Access Jenkins at http://${JENKINS_IP}:8080"
echo "2. Install required Jenkins plugins"
echo "3. Configure Jenkins credentials"
echo "4. Access Grafana at http://localhost:3000 (after port-forwarding)"
echo "5. Deploy your applications using the provided Jenkins pipeline"

# Save credentials to a secure file
echo "Saving credentials to credentials.txt..."
cat << EOF > ../credentials.txt
Database Password: ${DB_PASSWORD}
Grafana Admin Password: ${GRAFANA_PASSWORD}
Jenkins URL: http://${JENKINS_IP}:8080
Jenkins Initial Admin Password: ${JENKINS_PASSWORD}
EOF

chmod 600 ../credentials.txt

echo -e "\n${GREEN}Credentials have been saved to credentials.txt${NC}"
echo -e "${RED}IMPORTANT: Keep this file secure and delete it after recording the credentials!${NC}"
