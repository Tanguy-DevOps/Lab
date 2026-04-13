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

Run the bootstrap:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Then use the outputs to configure GitHub Actions and the root backend:

```bash
terraform output
```

Expected GitHub values:

* `AWS_ROLE_TO_ASSUME`: `github_actions_role_arn`
* `TF_STATE_BUCKET`: `terraform_state_bucket`
* `TF_STATE_KEY`: `terraform_state_key`
* `TF_STATE_REGION`: `terraform_state_region`

Expected root `backend.hcl`:

```hcl
bucket       = "<terraform_state_bucket>"
key          = "serveurtest1/terraform.tfstate"
region       = "eu-west-3"
encrypt      = true
use_lockfile = true
```

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
