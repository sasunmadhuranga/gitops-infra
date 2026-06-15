# ── Dev environment values ────────────────────────────────────────────────────
# Adjust these before running terraform apply.

aws_region   = "us-east-1"
project_name = "gitops-argocd"
environment  = "dev"

# Networking
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# EKS
eks_cluster_version = "1.33"
node_instance_type  = "t3.small"   # t3.micro is too small for EKS system pods
node_desired_count  = 2
node_min_count      = 2
node_max_count      = 3

# ECR
ecr_repo_name             = "gitops-app"
ecr_image_retention_count = 10
