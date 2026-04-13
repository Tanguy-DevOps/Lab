variable "aws_region" {
  description = "AWS region for the bootstrap resources."
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Short project name used in resource names and tags."
  type        = string
  default     = "serveurtest1"
}

variable "environment" {
  description = "Environment tag for bootstrap resources."
  type        = string
  default     = "bootstrap"
}

variable "terraform_state_bucket" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string

  validation {
    condition     = length(var.terraform_state_bucket) >= 3 && length(var.terraform_state_bucket) <= 63
    error_message = "terraform_state_bucket must be a valid S3 bucket name length."
  }
}

variable "terraform_state_key" {
  description = "S3 object key used by the root Terraform backend."
  type        = string
  default     = "serveurtest1/terraform.tfstate"
}

variable "enable_kms_encryption" {
  description = "Use a customer-managed AWS KMS key for Terraform state encryption."
  type        = bool
  default     = true
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period before deleting the Terraform state KMS key."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "noncurrent_state_retention_days" {
  description = "Number of days to retain noncurrent Terraform state object versions."
  type        = number
  default     = 365

  validation {
    condition     = var.noncurrent_state_retention_days >= 90
    error_message = "noncurrent_state_retention_days must be at least 90 for state recovery."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if it already exists in the AWS account."
  type        = bool
  default     = true
}

variable "github_oidc_provider_url" {
  description = "GitHub Actions OIDC provider URL."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "github_owner" {
  description = "GitHub owner or organization allowed to assume the deploy role."
  type        = string
  default     = "Tanguy-DevOps"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the deploy role."
  type        = string
  default     = "Lab"
}

variable "github_environment" {
  description = "GitHub Actions environment allowed to assume the role. Leave empty to use github_branch instead."
  type        = string
  default     = "production"
}

variable "github_branch" {
  description = "Fallback branch allowed to assume the role when github_environment is empty."
  type        = string
  default     = "infra/s3-backend-security-baseline"
}

variable "github_actions_role_name" {
  description = "IAM role name assumed by GitHub Actions for Terraform state access."
  type        = string
  default     = "serveurtest1-github-actions-terraform-state"
}

variable "tags" {
  description = "Extra tags applied to bootstrap resources."
  type        = map(string)
  default     = {}
}
