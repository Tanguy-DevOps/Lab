# CI/CD Guide

## Goal

This repository now contains:

* a **CI** workflow that validates the project automatically
* a **manual CD** workflow that deploys only when you explicitly trigger it

This is the safest starting point for an infrastructure lab.

## What CI does

File: `.github/workflows/ci.yml`

It runs automatically on `push` and `pull_request`.

It checks:

* Terraform formatting
* Terraform validation
* Ansible collection installation
* Ansible linting
* Ansible syntax
* shell script syntax
* secret scanning with Gitleaks
* Terraform security scanning with Checkov

The CI workflow does **not** deploy anything and initializes Terraform with
`-backend=false`, so validation does not need AWS access.

## What Manual CD does

File: `.github/workflows/manual-deploy.yml`

It runs only when you start it manually from the GitHub Actions tab.

It:

* installs Terraform and Ansible
* authenticates to AWS with GitHub Actions OIDC
* writes a temporary Terraform S3 backend config for the remote state
* writes a temporary `terraform.tfvars` file from GitHub secrets
* runs `terraform plan`
* runs `terraform apply` with the saved plan
* waits for SSH to become reachable
* runs the Ansible playbook

It deploys only if you type `APPLY` in the manual form.

## Terraform remote state

Terraform uses a partial S3 backend configuration in the repository. The real
backend values are supplied by `backend.hcl` locally or by GitHub Actions during
deployment.

Create the AWS S3 bucket outside this Terraform stack before the first remote
`terraform init`. The bucket must be private, versioned, encrypted, and blocked
from public access. If you use SSE-KMS, the GitHub OIDC role must also be able
to use the KMS key.

The expected IAM and KMS policies are documented in `docs/aws-iam-kms.md`.

Local setup:

```bash
cp backend.hcl.example backend.hcl
chmod 600 backend.hcl
terraform init -backend-config=backend.hcl
```

Default backend values:

* `region`: `eu-west-3`
* `key`: `serveurtest1/terraform.tfstate`
* `encrypt`: `true`
* `use_lockfile`: `true`

## GitHub Secrets to create

In GitHub:

`Settings` -> `Secrets and variables` -> `Actions`

Create these repository secrets:

* `HCLOUD_TOKEN`
* `HCLOUD_SSH_PUBLIC_KEY`
* `CLOUDFLARE_API_TOKEN`
* `CLOUDFLARE_ZONE_ID`
* `DOMAIN_NAME`
* `CERTBOT_EMAIL`
* `SSH_ALLOWED_CIDR`
* `SSH_PRIVATE_KEY`
* `AWS_ROLE_TO_ASSUME`

## GitHub variables to create

In GitHub:

`Settings` -> `Secrets and variables` -> `Actions` -> `Variables`

Create these repository variables:

* `TF_STATE_BUCKET`
* `TF_STATE_KEY` (optional, defaults to `serveurtest1/terraform.tfstate`)
* `TF_STATE_REGION` (optional, defaults to `eu-west-3`)

`TF_STATE_BUCKET` may also be stored as a secret if you prefer not to expose the
bucket name in repository variables.

## How to use CI

1. Push a branch to GitHub.
2. Open the `Actions` tab.
3. Open the `CI` workflow.
4. Check whether the job is green or red.

If it is red, GitHub shows the exact failing step.

## How to use Manual CD

1. Open the `Actions` tab.
2. Open `Manual Deploy`.
3. Click `Run workflow`.
4. Type `APPLY`.
5. Choose whether `certbot_staging` should be `true` or `false`.
6. Launch the workflow.

## Recommended usage

For a first production-like setup:

* use CI on every branch
* use Manual CD only after CI is green
* keep `certbot_staging=true` while testing
* switch to `false` only when you want a real trusted certificate

## Important note

This workflow uses GitHub-hosted runners.

That means:

* deployment happens from GitHub's temporary machine
* your secrets must exist in GitHub Actions secrets
* the SSH private key used by Ansible must match the public key sent to Hetzner
* the current secrets model and Vault introduction plan are documented in
  `docs/security.md`

## Next improvements

Useful next steps:

* protect the `production` environment with required reviewers
* split Terraform, Ansible, and docs into dedicated folders
* add security scanning for container images when container build artifacts exist
* add the Vault recovery runbook described in `docs/security.md`
