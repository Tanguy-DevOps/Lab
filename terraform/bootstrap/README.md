# Terraform Bootstrap

This layer creates the AWS resources required before the root Terraform stack can
use the S3 backend safely.

It manages:

* S3 bucket for Terraform state.
* Bucket versioning, encryption, and public access block.
* Lifecycle retention for noncurrent state versions.
* Optional customer-managed KMS key for state encryption.
* GitHub Actions OIDC provider.
* IAM role used by GitHub Actions.
* Least-privilege S3 and KMS policies for the state file and `.tflock`.
* Optional Vault prerequisites:
  * KMS key for Vault auto-unseal.
  * Private S3 bucket for Vault Raft snapshots.
  * Optional dedicated KMS key for Vault snapshot encryption.
  * IAM role and instance profile for a Vault node (auto-unseal + snapshot access).

## Why this is separate

The root stack stores its state in S3. That bucket and its IAM role must exist
before the root stack can run with the remote backend. This bootstrap layer is
therefore applied first and kept intentionally small.

## Usage

Create a local tfvars file:

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```

Edit `terraform.tfvars` and choose a globally unique S3 bucket name.

If you want to create Vault prerequisites in the same bootstrap run, set:

```hcl
enable_vault_prerequisites = true
vault_snapshot_bucket      = "<globally-unique-vault-snapshot-bucket>"
```

Recommended first pass: keep `enable_vault_prerequisites = false`, validate the
Terraform backend migration, then enable Vault resources in a dedicated apply.

Run the bootstrap with the project script (recommended):

```bash
cd ../..
./scripts/bootstrap-aws-foundation.sh
```

This script enforces:

* required local file `terraform/bootstrap/terraform.tfvars`,
* strict file permissions (`0600`),
* non-interactive Terraform plan (`-input=false`),
* backend synchronization after a successful apply.

Manual commands (advanced):

```bash
cd terraform/bootstrap
terraform init
terraform fmt -check
terraform validate
terraform plan -input=false -var-file=terraform.tfvars -out=tfplan
terraform apply tfplan
```

Then synchronize the root backend and print the exact GitHub values:

```bash
cd ../..
./scripts/sync-backend-from-bootstrap.sh
```

Expected GitHub values:

* `AWS_ROLE_TO_ASSUME`: `github_actions_role_arn`
* `TF_STATE_BUCKET`: `terraform_state_bucket`
* `TF_STATE_KEY`: `terraform_state_key`
* `TF_STATE_REGION`: `terraform_state_region`

When Vault prerequisites are enabled, useful outputs are:

* `vault_auto_unseal_kms_key_arn`
* `vault_snapshot_bucket`
* `vault_snapshot_prefix`
* `vault_snapshot_kms_key_arn`
* `vault_node_role_arn`
* `vault_node_instance_profile_name`

Expected root `backend.hcl`:

```hcl
bucket       = "<terraform_state_bucket>"
key          = "serveurtest1/terraform.tfstate"
region       = "eu-west-3"
encrypt      = true
use_lockfile = true
```

The script writes `backend.hcl` at the repository root with `0600` permissions.

## Safety

The state bucket has `force_destroy = false` and Terraform `prevent_destroy`
enabled. This is intentional: the state bucket is persistent recovery
infrastructure, not disposable compute.

Noncurrent state object versions are retained for 365 days by default. Tune
`noncurrent_state_retention_days` only after the restore process is tested.

If the AWS account already has a GitHub OIDC provider, set:

```hcl
create_github_oidc_provider = false
```

Do not store AWS access keys in GitHub Actions. Use the OIDC role output by this
bootstrap layer.
