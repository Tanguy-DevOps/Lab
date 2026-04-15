# Vault Bootstrap and Recovery Runbook

## Goal

This runbook defines how Vault should be introduced after the current S3
Terraform backend and CI/CD baseline.

Vault must not store production-critical secrets until this runbook has been
tested end to end:

* bootstrap with AWS KMS auto-unseal,
* snapshot backup to S3,
* isolated restore from a snapshot,
* access policy review,
* recovery key custody review.

## Target v1 design

The first Vault deployment should be a minimal lab deployment, not a full HA
cluster.

Initial choices:

* Vault storage: integrated storage with Raft.
* Seal: AWS KMS auto-unseal.
* Snapshot destination: encrypted private S3 bucket or prefix.
* Secrets migration: none at first, test secrets only.
* Network exposure: private only, no public route through Traefik.
* CI/CD dependency: GitHub Actions secrets stay in place until restore is proven.

Why this order:

* Raft integrated storage gives a clear snapshot and restore workflow.
* AWS KMS auto-unseal fits the existing AWS S3 backend direction.
* Keeping Vault private reduces blast radius while the lab is young.
* Delaying real secret migration avoids creating an unrecoverable dependency.

## Required AWS resources

Prepare these resources before deploying Vault:

* KMS key for Vault auto-unseal.
* S3 bucket or prefix for Vault snapshots.
* IAM role or instance profile for the Vault node.
* IAM policy allowing only the required KMS and S3 operations.

This repository can now provision those prerequisites from
`terraform/bootstrap` when `enable_vault_prerequisites=true`.

Expected Terraform bootstrap outputs for Vault wiring:

* `vault_auto_unseal_kms_key_arn`
* `vault_snapshot_bucket`
* `vault_snapshot_prefix`
* `vault_snapshot_kms_key_arn`
* `vault_node_role_arn`
* `vault_node_instance_profile_name`

Policy templates are documented in `docs/aws-iam-kms.md`.

The KMS key is critical infrastructure. If the AWS KMS key used for auto-unseal
is deleted or permanently unavailable, Vault may not be recoverable even if
snapshots still exist. Protect it with deletion windows, restricted admins, and
clear ownership.

## Bootstrap checklist

Before starting Vault:

* Confirm the Vault node is private.
* Confirm only operator access can reach port `8200`.
* Confirm the node can call AWS KMS.
* Confirm the node can write snapshots to the S3 destination.
* Confirm system time is synchronized.
* Confirm no real application secret will be written during the first test.

Expected Vault configuration shape:

```hcl
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-1"
}

seal "awskms" {
  region     = "eu-west-3"
  kms_key_id = "<vault-auto-unseal-kms-key-id>"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = false
}

api_addr     = "https://<vault-private-dns>:8200"
cluster_addr = "https://<vault-private-dns>:8201"
disable_mlock = true
```

The exact paths, TLS files, DNS names, and systemd unit belong in the future
Ansible implementation.

## Initialize Vault

Run initialization only once on a fresh Vault storage backend.

Recommended shape:

```bash
export VAULT_ADDR="https://<vault-private-dns>:8200"
vault status
vault operator init \
  -recovery-shares=5 \
  -recovery-threshold=3 \
  -format=json
vault status
```

With AWS KMS auto-unseal, initialization produces recovery keys instead of
manual unseal keys. Recovery keys must be distributed to separate trusted
operators and must never be committed, pasted into chat, or stored in the repo.

The initial root token is temporary. Use it only to create the first operator
policies and authentication methods, then revoke or retire it.

## Minimum post-bootstrap tasks

Before storing any important secret:

* Enable audit logging.
* Create least-privilege policies for `admin`, `ops`, `ci`, and later `app`.
* Create a short-lived operator login path.
* Confirm `vault status` reports initialized and unsealed.
* Restart the Vault service and confirm auto-unseal works.
* Write one test secret and read it back.
* Delete the test secret.
* Save and restore a snapshot in an isolated environment.

Example checks:

```bash
vault status
systemctl restart vault
vault status
vault kv put secret/lab-smoke-test value=test-only
vault kv get secret/lab-smoke-test
vault kv delete secret/lab-smoke-test
```

## Snapshot backup procedure

Manual snapshot procedure:

```bash
export VAULT_ADDR="https://<vault-private-dns>:8200"
export SNAPSHOT_DATE="$(date -u +%Y%m%dT%H%M%SZ)"
vault operator raft snapshot save "vault-${SNAPSHOT_DATE}.snap"
vault operator raft snapshot inspect "vault-${SNAPSHOT_DATE}.snap"
aws s3 cp \
  "vault-${SNAPSHOT_DATE}.snap" \
  "s3://<vault-snapshot-bucket>/vault/raft/vault-${SNAPSHOT_DATE}.snap" \
  --sse aws:kms \
  --sse-kms-key-id "<vault-snapshot-kms-key-id>"
```

Snapshot requirements:

* Snapshots are sensitive and must be encrypted.
* S3 bucket public access must be blocked.
* Versioning must be enabled.
* Access must be limited to Vault operators and recovery automation.
* Snapshot integrity must be checked after upload.
* Retention must balance recovery needs and cost.

Suggested first retention:

* Daily snapshots for 7 days.
* Weekly snapshots for 4 weeks.
* Manual snapshot before every Vault upgrade or policy migration.

## Restore drill procedure

Always run restore tests in an isolated environment. Do not connect a restore
test Vault to live applications or live automation.

High-level restore flow:

1. Create a fresh isolated Vault node with the same seal strategy.
2. Start Vault with empty Raft storage.
3. Initialize the temporary cluster.
4. Authenticate with the temporary root token.
5. Download the target snapshot from S3.
6. Restore it with `-force`.
7. Restart Vault.
8. Confirm auto-unseal works through AWS KMS.
9. Confirm policies, auth methods, and test secrets are present.
10. Destroy the isolated restore environment after validation.

Command shape:

```bash
export VAULT_ADDR="https://<isolated-vault-private-dns>:8200"
vault operator init -recovery-shares=5 -recovery-threshold=3 -format=json
aws s3 cp \
  "s3://<vault-snapshot-bucket>/vault/raft/<snapshot-file>.snap" \
  "/tmp/<snapshot-file>.snap"
vault login "<temporary-root-token>"
vault operator raft snapshot restore -force "/tmp/<snapshot-file>.snap"
systemctl restart vault
vault status
```

The recovery keys and root token from the restored snapshot supersede the
temporary values created for the empty cluster. Document who holds the original
recovery keys before running restore drills.

## Go or no-go gates

Vault may store real deployment secrets only when all gates are green:

* Auto-unseal works after a service restart.
* Auto-unseal works after node recreation.
* A snapshot has been saved, uploaded, downloaded, inspected, and restored.
* The KMS key deletion policy and IAM ownership are reviewed.
* Root token handling is documented.
* Recovery keys are split across operators.
* Audit logging is enabled.
* CI/CD has a non-static authentication path to Vault.
* A rollback path exists for keeping secrets in GitHub Actions.

Until then, GitHub Actions remains the source for deployment secrets.

## Failure modes

KMS key unavailable:

* Vault may remain sealed.
* Check AWS KMS availability, IAM permissions, and key state.
* Do not rotate or delete the KMS key without a tested migration.

Snapshot missing or corrupted:

* Do not migrate additional secrets.
* Restore from an older snapshot if available.
* Review S3 versioning, retention, and upload validation.

Recovery keys unavailable:

* Do not proceed with critical operations that require recovery quorum.
* Review key custody and operator coverage before storing real secrets.

Vault node lost:

* Recreate the node through automation.
* Restore Raft data from S3 snapshot if local data is gone.
* Confirm auto-unseal and audit logging before resuming migrations.

## References

* HashiCorp Vault integrated storage:
  https://developer.hashicorp.com/vault/docs/configuration/storage/raft
* HashiCorp Vault seal and auto-unseal:
  https://developer.hashicorp.com/vault/docs/concepts/seal
* HashiCorp Vault AWS KMS seal:
  https://developer.hashicorp.com/vault/docs/configuration/seal/awskms
* HashiCorp Vault operator init:
  https://developer.hashicorp.com/vault/docs/commands/operator/init
* HashiCorp Vault Raft snapshot commands:
  https://developer.hashicorp.com/vault/docs/commands/operator/raft
* HashiCorp Vault snapshot save:
  https://developer.hashicorp.com/vault/docs/sysadmin/snapshots/save
* HashiCorp Vault snapshot restore:
  https://developer.hashicorp.com/vault/docs/sysadmin/snapshots/restore
