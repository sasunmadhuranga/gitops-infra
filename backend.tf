# ── Terraform State Backend ───────────────────────────────────────────────────
# By default Terraform stores state locally (terraform.tfstate).
# For a real project, store it remotely in S3 so you don't lose it.
#
# To enable:
#   1. Create an S3 bucket: aws s3 mb s3://your-tfstate-bucket --region us-east-1
#   2. Create a DynamoDB table for state locking:
#        aws dynamodb create-table \
#          --table-name terraform-state-lock \
#          --attribute-definitions AttributeName=LockID,AttributeType=S \
#          --key-schema AttributeName=LockID,KeyType=HASH \
#          --billing-mode PAY_PER_REQUEST \
#          --region us-east-1
#   3. Uncomment the block below and fill in your bucket name.
#   4. Run: terraform init -reconfigure

# terraform {
#   backend "s3" {
#     bucket         = "your-tfstate-bucket"
#     key            = "gitops-argocd/dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
