output "terraform_state_bucket" {
  description = "S3 bucket name for the root Terraform backend."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_key" {
  description = "S3 key for the root Terraform backend."
  value       = var.terraform_state_key
}

output "terraform_state_region" {
  description = "AWS region for the root Terraform backend."
  value       = var.aws_region
}

output "terraform_state_kms_key_arn" {
  description = "KMS key ARN for Terraform state encryption, if enabled."
  value       = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].arn : null
}

output "github_actions_role_arn" {
  description = "Role ARN to store as AWS_ROLE_TO_ASSUME in GitHub Actions secrets."
  value       = aws_iam_role.github_actions_terraform_state.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN used by the trust policy."
  value       = local.github_oidc_provider_arn
}

output "github_oidc_subject" {
  description = "GitHub OIDC subject allowed by the trust policy."
  value       = local.github_subject
}

output "backend_hcl" {
  description = "Backend config values for the root Terraform stack."
  value = {
    bucket       = aws_s3_bucket.terraform_state.bucket
    key          = var.terraform_state_key
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}
