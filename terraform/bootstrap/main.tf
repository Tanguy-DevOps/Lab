terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  github_repository      = "${var.github_owner}/${var.github_repo}"
  github_oidc_hostpath   = replace(var.github_oidc_provider_url, "https://", "")
  github_subject         = var.github_environment != "" ? "repo:${local.github_repository}:environment:${var.github_environment}" : "repo:${local.github_repository}:ref:refs/heads/${var.github_branch}"
  terraform_lockfile_key = "${var.terraform_state_key}.tflock"

  tags = merge(
    {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Layer       = "bootstrap"
      Environment = var.environment
    },
    var.tags
  )
}

# If the AWS account already has a GitHub OIDC provider, set
# create_github_oidc_provider=false and let this data source reference it.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = var.github_oidc_provider_url
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = var.github_oidc_provider_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "terraform_state_kms_key" {
  #checkov:skip=CKV_AWS_109:KMS key policies use Resource "*" because the key policy is attached to the key itself.
  #checkov:skip=CKV_AWS_111:KMS key admin delegation is scoped to the account root principal for IAM policy enablement.
  #checkov:skip=CKV_AWS_356:KMS key policies require Resource "*" for statements attached directly to the key.
  count = var.enable_kms_encryption ? 1 : 0

  statement {
    sid    = "EnableIamPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "terraform_state" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "KMS key for ${var.project_name} Terraform state"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.terraform_state_kms_key[0].json
}

resource "aws_kms_alias" "terraform_state" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/${var.project_name}-terraform-state"
  target_key_id = aws_kms_key.terraform_state[0].key_id
}

resource "aws_s3_bucket" "terraform_state" {
  #checkov:skip=CKV_AWS_18:Access logging requires a dedicated log bucket; add it in the next AWS hardening pass.
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally deferred for this cost-minimal lab bootstrap.
  #checkov:skip=CKV_AWS_145:KMS encryption is configured by aws_s3_bucket_server_side_encryption_configuration when enable_kms_encryption=true, which is the default.
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed until monitoring automation consumes state bucket events.
  bucket        = var.terraform_state_bucket
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "retain-noncurrent-state-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_state_retention_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_kms" {
  count = var.enable_kms_encryption ? 1 : 0

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_aes" {
  count = var.enable_kms_encryption ? 0 : 1

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "terraform_state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_bucket.json
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_hostpath}:sub"
      values   = [local.github_subject]
    }
  }
}

resource "aws_iam_role" "github_actions_terraform_state" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  description        = "GitHub Actions role for ${var.project_name} Terraform state access"
}

data "aws_iam_policy_document" "terraform_state_access" {
  statement {
    sid       = "ListTerraformStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [var.terraform_state_key]
    }
  }

  statement {
    sid    = "ReadWriteTerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = ["${aws_s3_bucket.terraform_state.arn}/${var.terraform_state_key}"]
  }

  statement {
    sid    = "ReadWriteDeleteTerraformLockfile"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.terraform_state.arn}/${local.terraform_lockfile_key}"]
  }
}

resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-access"
  description = "Least-privilege access to ${var.project_name} Terraform state and lockfile"
  policy      = data.aws_iam_policy_document.terraform_state_access.json
}

resource "aws_iam_role_policy_attachment" "terraform_state_access" {
  role       = aws_iam_role.github_actions_terraform_state.name
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

data "aws_iam_policy_document" "terraform_state_kms_access" {
  count = var.enable_kms_encryption ? 1 : 0

  statement {
    sid    = "UseTerraformStateKmsKeyThroughS3"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]

    resources = [aws_kms_key.terraform_state[0].arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"

      values = [
        "${aws_s3_bucket.terraform_state.arn}/${var.terraform_state_key}",
        "${aws_s3_bucket.terraform_state.arn}/${local.terraform_lockfile_key}",
      ]
    }
  }
}

resource "aws_iam_policy" "terraform_state_kms_access" {
  count = var.enable_kms_encryption ? 1 : 0

  name        = "${var.project_name}-terraform-state-kms-access"
  description = "KMS access for ${var.project_name} Terraform state"
  policy      = data.aws_iam_policy_document.terraform_state_kms_access[0].json
}

resource "aws_iam_role_policy_attachment" "terraform_state_kms_access" {
  count = var.enable_kms_encryption ? 1 : 0

  role       = aws_iam_role.github_actions_terraform_state.name
  policy_arn = aws_iam_policy.terraform_state_kms_access[0].arn
}
