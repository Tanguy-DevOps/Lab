# AWS IAM and KMS Policy Guide

## Goal

This document defines the minimum AWS access model for the current Terraform S3
backend and the future Vault deployment.

The policies below are templates. Replace every placeholder before using them:

* `<aws-account-id>`
* `<github-owner>`
* `<github-repo>`
* `<terraform-state-bucket>`
* `<terraform-state-kms-key-arn>`
* `<vault-snapshot-bucket>`
* `<vault-auto-unseal-kms-key-arn>`
* `<vault-snapshot-kms-key-arn>`

Current repository values:

* GitHub repository: `Tanguy-DevOps/Lab`
* AWS region: `eu-west-3`
* Terraform state key: `serveurtest1/terraform.tfstate`
* Terraform lockfile key: `serveurtest1/terraform.tfstate.tflock`
* GitHub deployment environment: `production`

## GitHub OIDC trust policy

Use this trust policy for the role stored in `AWS_ROLE_TO_ASSUME`.

Preferred production trust is tied to the GitHub Actions environment because the
manual deploy workflow uses `environment: production`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<aws-account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<github-owner>/<github-repo>:environment:production"
        }
      }
    }
  ]
}
```

If the environment-based subject does not match during initial bootstrapping,
use a temporary branch-scoped policy and replace it after the first successful
deploy test:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<aws-account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<github-owner>/<github-repo>:ref:refs/heads/infra/s3-backend-security-baseline"
        }
      }
    }
  ]
}
```

Do not use an organization-wide wildcard for this role.

## Terraform state role policy

Attach this policy to the GitHub OIDC role used by the manual deploy workflow.

It permits:

* listing only the Terraform state prefix,
* reading and writing the state object,
* reading, writing, and deleting only the `.tflock` lock object.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListTerraformStatePrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<terraform-state-bucket>",
      "Condition": {
        "StringEquals": {
          "s3:prefix": "serveurtest1/terraform.tfstate"
        }
      }
    },
    {
      "Sid": "ReadWriteTerraformState",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::<terraform-state-bucket>/serveurtest1/terraform.tfstate"
    },
    {
      "Sid": "ReadWriteDeleteTerraformLockfile",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::<terraform-state-bucket>/serveurtest1/terraform.tfstate.tflock"
    }
  ]
}
```

Terraform does not need `s3:DeleteObject` on the state file.

## Terraform state KMS policy

If the Terraform state bucket uses SSE-KMS, add this policy to the same GitHub
OIDC role and allow the role in the KMS key policy.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UseTerraformStateKmsKeyThroughS3",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Resource": "<terraform-state-kms-key-arn>",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.eu-west-3.amazonaws.com"
        },
        "StringLike": {
          "kms:EncryptionContext:aws:s3:arn": [
            "arn:aws:s3:::<terraform-state-bucket>/serveurtest1/terraform.tfstate",
            "arn:aws:s3:::<terraform-state-bucket>/serveurtest1/terraform.tfstate.tflock"
          ]
        }
      }
    }
  ]
}
```

The KMS key policy must also permit the role. IAM permissions alone are not
enough if the key policy does not allow that principal to use the key.

## Terraform state bucket controls

The state bucket must have:

* public access block enabled,
* versioning enabled,
* server-side encryption enabled,
* no public bucket policy,
* least-privilege bucket policy if a bucket policy is used,
* lifecycle rules reviewed before deleting old versions,
* access logs or CloudTrail data events considered before production use.

Do not enable force-delete style cleanup for this bucket. The state bucket is a
recovery control, not disposable compute.

## Future Vault node IAM policy

Vault should use a dedicated IAM role or instance profile. Do not reuse the
GitHub Actions Terraform state role.

For AWS KMS auto-unseal, Vault needs only these KMS permissions on the
auto-unseal key:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VaultAutoUnseal",
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "<vault-auto-unseal-kms-key-arn>"
    }
  ]
}
```

For S3 snapshot upload and restore, add a separate policy statement scoped to
the snapshot prefix:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListVaultSnapshotPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<vault-snapshot-bucket>",
      "Condition": {
        "StringLike": {
          "s3:prefix": "vault/raft/*"
        }
      }
    },
    {
      "Sid": "ReadWriteVaultSnapshots",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::<vault-snapshot-bucket>/vault/raft/*"
    }
  ]
}
```

If snapshots use SSE-KMS, add KMS access through S3:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UseVaultSnapshotKmsKeyThroughS3",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Resource": "<vault-snapshot-kms-key-arn>",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.eu-west-3.amazonaws.com"
        },
        "StringLike": {
          "kms:EncryptionContext:aws:s3:arn": "arn:aws:s3:::<vault-snapshot-bucket>/vault/raft/*"
        }
      }
    }
  ]
}
```

## Separation rules

Keep these principals separate:

* GitHub OIDC role for Terraform state access.
* Vault node role for auto-unseal and snapshot access.
* Human admin role for creating and managing KMS keys.
* Break-glass role for emergency recovery.

Do not give CI broad KMS administration permissions. CI should use keys, not
own keys.

Do not give Vault access to the Terraform state bucket unless a specific restore
procedure requires it.

## Validation checklist

Before enabling the Terraform S3 backend in GitHub Actions:

* OIDC provider `token.actions.githubusercontent.com` exists in AWS IAM.
* `AWS_ROLE_TO_ASSUME` points to the Terraform state role.
* Role trust policy restricts `aud` to `sts.amazonaws.com`.
* Role trust policy restricts `sub` to the repository and environment or branch.
* S3 access is limited to the state key and lockfile key.
* KMS policy, if used, is limited to the Terraform state key paths.
* A failed deploy cannot access unrelated buckets or KMS keys.

Before deploying Vault:

* Vault has a dedicated AWS principal.
* Vault auto-unseal key policy allows only the Vault principal and key admins.
* Vault snapshot bucket is private, encrypted, and versioned.
* Snapshot restore has a documented isolated test environment.
* Recovery key custody is documented.

## References

* Terraform S3 backend permissions:
  https://developer.hashicorp.com/terraform/language/settings/backends/s3
* GitHub OIDC reference:
  https://docs.github.com/en/actions/reference/security/oidc
* AWS OIDC role trust policy examples:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html
* AWS IAM OIDC condition keys:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html
* AWS KMS key policies:
  https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
* AWS KMS least-privilege guidance:
  https://docs.aws.amazon.com/kms/latest/developerguide/least-privilege.html
* Vault AWS KMS seal permissions:
  https://developer.hashicorp.com/vault/docs/configuration/seal/awskms
