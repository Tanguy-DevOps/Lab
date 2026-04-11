# Project Vision

This project is a **DevOps Infrastructure Lab** designed to simulate real-world production environments.

It serves three main purposes:
- Experimentation platform  
- Continuous learning system  
- Professional DevOps portfolio  

The goal is **not** to build a simple infrastructure, but to:
- deeply understand each component  
- reproduce real production scenarios  
- design resilient and scalable systems  

> This is a **production-like environment**, not a demo.

---

# Learning Approach

This project follows an **iterative and progressive learning strategy**:

- Learn by building real infrastructure  
- Experiment with failure scenarios  
- Improve through iteration  
- Document technical decisions and incidents  

## Expected Behavior (Codex)

- Do not oversimplify solutions  
- Prefer realistic implementations over shortcuts  
- Always explain trade-offs when introducing components  

---

# Tech Stack

## Infrastructure as Code
- Terraform → provisioning (servers, network, load balancer)  
- Ansible → system configuration and deployment  

## Containers & Orchestration
- Docker → packaging services  
- Kubernetes (k3s) → orchestration, scaling, failover  

## Networking
- Traefik → reverse proxy, ingress, TLS  

## Observability
- Prometheus → metrics  
- Grafana → dashboards  
- Loki (optional) → centralized logs  

## Automation
- n8n → workflows (alerts, backup, recovery)  

## Data & Storage
- PostgreSQL → replication / HA patterns  
- MinIO / S3 → object storage & backups (critical persistence layer)  

## CI/CD
- GitHub Actions (preferred)  

## Secrets
- KMS
- Vault

Requirements:
- Validate infrastructure before apply  
- Ensure reproducibility  
- Support safe iteration  

---

# Architecture

Clients → Traefik → Kubernetes Cluster

## Core Principles

- The cluster is ephemeral and reproducible  
- It can be destroyed and recreated at any time  

## State Management

All stateful components must externalize their data:
- Object storage (S3)  
- External databases  
- Backup systems  

## Namespaces

app:
- Web applications  
- APIs  
- Internal dashboard  

infra:
- PostgreSQL  
- MinIO / S3  
- Prometheus + Grafana  
- n8n  
- Vault

> The cluster itself is not persistent.  
> All critical data must survive its destruction.

---

# Infrastructure Layout

## Target Topology (logical)

- 1 control plane node  
- 3 Kubernetes worker nodes  
- 2 PostgreSQL nodes  
- 1 load balancer  
- 1 ops node (monitoring + automation)  
- 1 Vault node (with snapshot to S3)

## Key Principles

- Infrastructure is on-demand  
- Nodes are:
  - provisioned when needed  
  - destroyed when unused  
  - recreated via automation  

## Persistent Elements

- Terraform state → remote backend (S3)  
- Backups → object storage  
- Secrets → external systems (Vault / CI / KMS)  

> No critical state must depend on node lifetime.

---

# Automation Workflow

## Bootstrap

A script must:

### Collect inputs
- Number of nodes  
- Machine types  
- Domain  
- Services to deploy  

### Generate dynamically
- Terraform variables  
- Ansible inventory  
- Kubernetes / Helm configs  

### Execute
terraform apply  
ansible-playbook  
kubectl apply  

## Destroy

terraform destroy  

## Requirements

Infrastructure must be:
- Reproducible  
- Disposable  
- Cost-efficient  
- Version-controlled  
- Ephemeral by design  

Persistent state must always be externalized.

---

# Use Cases

- Load testing  
- Failover simulation  
- Service recovery  
- Backup / restore validation  
- CI/CD validation  
- Multi-environment experiments  
- Full infrastructure recovery testing  

---

# Repository Structure

project-root/  
├── terraform/  
├── ansible/  
├── k8s/  
├── scripts/  
├── dashboard/  
├── docs/  
└── .github/workflows/  

---

# Git Workflow Rules

## Branching Strategy

- main → stable & validated  
- dev → integration branch  

Branches:
- feature/* → new features  
- infra/* → infrastructure changes  
- fix/* → bug fixes  
- docs/* → documentation  

## Commit Rules

- Atomic and explicit commits  
- One logical change per commit  
- Avoid mixing concerns  

### Examples

feat(terraform): add load balancer module  
fix(ansible): correct PostgreSQL replication task  
chore(k8s): reorganize namespace manifests  
docs(security): add backup recovery procedure  

## Pull Requests

Must include:
- Goal  
- Impacted components  
- Risks  
- Validation performed  

Infrastructure PRs must include:
- Rollback strategy  

## Forbidden Actions

- Never commit secrets  
- Never commit sensitive generated files  
- Never force push to main  
- Never bypass reviews  

---

# CI/CD Requirements

## CI Goals

Automatically validate:
- Terraform (fmt + validate)  
- Ansible (syntax + lint)  
- Kubernetes manifests  
- YAML consistency  
- Shell scripts quality  

## CD Goals

- Reproducible deployments  
- Minimal manual steps  
- Rollback-ready  
- No unsafe live changes  

## Pipeline Stages

- lint  
- validate  
- security checks  
- plan  
- deploy (manual approval only)  

## Safety Rules

- No deploy from unreviewed branches  
- Destructive ops require explicit intent  
- Logs must be readable  
- Failures must block deployment  
- No secrets in logs  

---

# Engineering Principles

- Everything must be reproducible  
- No configuration drift  
- No hardcoded secrets  
- Modular infrastructure  
- Production-like systems  
- Documentation evolves with code  

> Favor stateless compute + external persistent state

---

# Security Requirements (MANDATORY)

## Access Control

- Least privilege  
- Dedicated service accounts  
- Role separation (admin / ops / app)  

## Secrets Management

- Never store secrets in Git  
- Use external providers (Vault / CI / KMS)  
- Rotate credentials regularly  
- No long-lived secrets on disk  

## Key Management (KMS)

Responsibilities:
- Key generation & storage  
- Encryption / decryption  
- IAM-based access control  

Use cases:
- S3 encryption  
- Vault auto-unseal  
- Sensitive data protection  

## Vault

- Must be backed up (snapshots → S3)  
- Can run:
  - Persistent mode  
  - Ephemeral + restore  

Loss of Vault without backup = total loss of secrets  

## Terraform

- Must put the sensible backend (.tfstate) on S3

---

# Kubernetes Security

- Non-root containers  
- No privileged containers unless justified  
- Minimal host access  

## Network Security

- Only Traefik is public  
- Internal services stay private  
- Enforce TLS  

## Node Hardening

- Minimal OS  
- Regular updates  
- Secure kubeconfig  

## Supply Chain

- Trusted images only  
- Pin versions  
- Scan dependencies  

---

# Monitoring & Audit

- Detect anomalies & failures  
- Track infrastructure events  
- Monitor certificates  

---

# Backup & Recovery

- Encrypted backups  
- Tested restoration  
- Documented procedures  

## S3 Requirements

- Private access  
- Encryption enabled  
- Versioning enabled  
- Strict IAM policies  

Used for:
- Terraform state  
- Vault snapshots  
- Application backups  

Backups are highly sensitive data  

---

# Validation

Before any deployment:

- Terraform validated  
- Ansible linted  
- Kubernetes configs validated  
- CI checks green  
- No secret exposure  
- Backup integrity verified  

---

# Codex Behavior Rules

Codex must:

- Respect full architecture  
- Prioritize automation  
- Maintain Git discipline  
- Preserve CI/CD integrity  
- Avoid shortcuts  
- Maintain production-level quality  

## When making changes

- Prefer small commits  
- Explain infrastructure impact  
- Suggest CI/CD updates  
- Keep branch intent clear  

---

# Forbidden Actions

- Hardcoding secrets  
- Bypassing security controls  
- Manual drift  
- Exposing internal services  
- Unjustified privileged containers  
- Direct pushes to stable branches  
- Disabling CI checks  

---

# Final Objective

Build a realistic, secure, scalable, and automated DevOps infrastructure capable of:

- Simulating production systems  
- Being deployed on demand  
- Handling stress and failure scenarios  
- Demonstrating advanced DevOps skills  
- Showcasing strong Git, CI/CD, and operational discipline  