variable "project_name"       { type = string }
variable "environment"        { type = string }
variable "cluster_name"       { type = string }
variable "cluster_version"    { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_instance_type" { type = string }
variable "node_desired_count" { type = number }
variable "node_min_count"     { type = number }
variable "node_max_count"     { type = number }
variable "node_role_arn"      { type = string }
variable "cluster_role_arn"   { type = string }

data "aws_caller_identity" "current" {}
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ─── Control Plane Security Group ─────────────────────────────────────────────
# Controls which traffic can reach the EKS API server.

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-cluster-sg" }
}

# Allow nodes to talk to the control plane
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow worker nodes to reach API server"
}

# ─── Node Security Group ──────────────────────────────────────────────────────

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inter-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Allow control plane to reach nodes (kubelet, webhooks)"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  ingress {
    description = "Allow ALB to reach app pods on port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (ECR pulls, AWS APIs, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-node-sg" }
}

# ─── EKS Cluster ──────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true   # Allows kubectl from your local machine
  }

  # Enable useful control-plane log groups in CloudWatch
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_security_group.cluster]
}

# ─── OIDC Identity Provider ───────────────────────────────────────────────────
# Enables IAM Roles for Service Accounts (IRSA). Required for the AWS Load
# Balancer Controller (and ArgoCD Image Updater) to call AWS APIs securely.

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ─── Managed Node Group ───────────────────────────────────────────────────────
# Nodes are spread across private subnets in both AZs automatically.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_count
    min_size     = var.node_min_count
    max_size     = var.node_max_count
  }

  update_config {
    max_unavailable = 1   # Rolling update: replaces one node at a time
  }

  # Use AL2 (Amazon Linux 2) — the standard, well-tested EKS node AMI
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 20   # GB — enough for system + a few container images

  labels = {
    environment = var.environment
    role        = "worker"
  }

  depends_on = [aws_eks_cluster.main]
}

# ─── Outputs ──────────────────────────────────────────────────────────────────

output "cluster_name"        { value = aws_eks_cluster.main.name }
output "cluster_endpoint"    { value = aws_eks_cluster.main.endpoint }
output "cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}
output "oidc_provider_arn"   { value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_provider_url"   { value = aws_iam_openid_connect_provider.eks.url }
output "node_sg_id"          { value = aws_security_group.nodes.id }
