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

output "vault_snapshot_bucket" {
  description = "S3 bucket name for Vault Raft snapshots when Vault prerequisites are enabled."
  value       = var.enable_vault_prerequisites ? aws_s3_bucket.vault_snapshots[0].bucket : null
}

output "vault_snapshot_prefix" {
  description = "S3 prefix used for Vault Raft snapshots."
  value       = var.enable_vault_prerequisites ? local.vault_snapshot_prefix : null
}

output "vault_auto_unseal_kms_key_arn" {
  description = "KMS key ARN used for Vault auto-unseal."
  value       = var.enable_vault_prerequisites ? aws_kms_key.vault_auto_unseal[0].arn : null
}

output "vault_snapshot_kms_key_arn" {
  description = "KMS key ARN used for Vault snapshot bucket encryption when enabled."
  value       = var.enable_vault_prerequisites && var.enable_vault_snapshot_kms_encryption ? aws_kms_key.vault_snapshot[0].arn : null
}

output "vault_node_role_arn" {
  description = "IAM role ARN for the Vault node instance profile."
  value       = var.enable_vault_prerequisites ? aws_iam_role.vault_node[0].arn : null
}

output "vault_node_instance_profile_name" {
  description = "Instance profile name to attach to the Vault node."
  value       = var.enable_vault_prerequisites ? aws_iam_instance_profile.vault_node[0].name : null
}
