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
* Ansible syntax
* shell script syntax

The CI workflow does **not** deploy anything.

## What Manual CD does

File: `.github/workflows/manual-deploy.yml`

It runs only when you start it manually from the GitHub Actions tab.

It:

* installs Terraform and Ansible
* writes a temporary `terraform.tfvars` file from GitHub secrets
* runs `terraform apply`
* waits for SSH to become reachable
* runs the Ansible playbook

It deploys only if you type `APPLY` in the manual form.

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

## Next improvements

Useful next steps:

* add `terraform plan` as a separate manual or automatic job
* add `ansible-lint`
* protect the `production` environment with required reviewers
* split Terraform, Ansible, and docs into dedicated folders
