# Security and Secrets Guide

## Goal

This document defines the current security model and the next steps before
introducing Vault.

The project is moving toward the target described in `AGENTS.md`, but Vault must
not become a critical dependency before backup, restore, access control, and
auto-unseal are designed and tested.

## Current secrets model

Secrets currently live in two places:

* Local development: `terraform.tfvars`, SSH private key, and AWS credentials or
  local AWS profile.
* GitHub Actions: repository secrets and variables used by the manual deployment
  workflow.

The repository must never contain:

* Terraform state files.
* Real `terraform.tfvars` files.
* Real `backend.hcl` files.
* SSH private keys.
* Cloud provider tokens.
* Vault tokens or unseal keys.
* Application passwords or database credentials.

Current Git ignore rules cover the main local risks:

* `*.tfstate`
* `terraform.tfvars`
* `backend.hcl`
* Terraform plan files
* generated Ansible inventory
* downloaded Ansible collections

## GitHub Actions secrets

These secrets are expected for the current deployment flow:

* `HCLOUD_TOKEN`
* `HCLOUD_SSH_PUBLIC_KEY`
* `CLOUDFLARE_API_TOKEN`
* `CLOUDFLARE_ZONE_ID`
* `DOMAIN_NAME`
* `CERTBOT_EMAIL`
* `SSH_ALLOWED_CIDR`
* `SSH_PRIVATE_KEY`
* `AWS_ROLE_TO_ASSUME`

These variables configure the Terraform remote state:

* `TF_STATE_BUCKET`
* `TF_STATE_KEY`, default: `serveurtest1/terraform.tfstate`
* `TF_STATE_REGION`, default: `eu-west-3`

`AWS_ROLE_TO_ASSUME` should use GitHub Actions OIDC. Do not use long-lived AWS
access keys in GitHub unless there is a temporary break-glass reason.

## AWS S3 and KMS baseline

The Terraform state bucket is created outside this Terraform stack for now. It
must use:

* private access only,
* public access block,
* bucket versioning,
* server-side encryption,
* least-privilege IAM,
* object lock or retention policy later if recovery requirements demand it.

If SSE-KMS is enabled, the GitHub OIDC role needs the minimum KMS permissions
required to read and write the state objects. The same AWS KMS approach is the
preferred future default for Vault auto-unseal.

## Vault introduction plan

Vault should be introduced in phases.

Phase 0: design and prerequisites

* Keep current secrets in GitHub Actions.
* Create the AWS KMS key strategy for Vault auto-unseal.
* Decide whether Vault runs as a dedicated node first or later inside k3s.
* Define the S3 snapshot destination and retention policy.
* Define operator roles: `admin`, `ops`, `ci`, and later `app`.
* Document recovery steps before storing critical secrets.

Phase 1: minimal Vault lab

* Deploy a single Vault instance for the lab only.
* Enable AWS KMS auto-unseal.
* Enable encrypted snapshots to S3.
* Create initial policies and short-lived tokens.
* Store only non-critical test secrets first.
* Prove restore from snapshot before migrating real deployment secrets.

Phase 2: controlled migration

* Move cloud provider tokens from GitHub Actions to Vault only when CI can read
  them through a least-privilege path.
* Rotate migrated secrets immediately after moving them.
* Keep emergency access documented and time-limited.
* Audit all accesses and failed attempts.

## Do not migrate yet

Do not move critical secrets into Vault until these checks are true:

* Vault has a documented restore procedure.
* A snapshot restore has been tested.
* Auto-unseal works after instance recreation.
* S3 snapshot storage is private, encrypted, and versioned.
* The initial policies are reviewed.
* CI/CD can authenticate without static long-lived Vault tokens.

## Next security improvements

Recommended next steps:

* Add secret scanning to CI.
* Add Terraform security scanning.
* Add an AWS IAM policy example for Terraform state access.
* Add an AWS KMS policy example for future Vault auto-unseal.
* Add a Vault recovery runbook before deploying Vault.
