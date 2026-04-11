# AGENTS.md

## 🧠 Project Vision

This project is a **DevOps Infrastructure Lab** designed to simulate real-world production environments.

It serves three purposes:

* experimentation platform
* continuous learning system
* professional DevOps portfolio

The goal is not to build a simple infrastructure, but to:

* understand each component deeply
* reproduce real production scenarios
* design resilient and scalable systems

This is a production-like environment, not a demo.

---

## 📚 Learning Approach

This project follows an iterative and progressive learning strategy:

* learn by building real infrastructure
* experiment with failure scenarios
* improve through iteration
* document technical decisions and incidents

Codex must respect this philosophy:

* do not oversimplify solutions
* prefer realistic implementations over shortcuts
* explain trade-offs when introducing new components

---

## 🧱 Tech Stack

### Infrastructure as Code

* Terraform → provisioning (servers, network, load balancer)
* Ansible → system configuration and deployment

### Containers & Orchestration

* Docker → packaging services
* Kubernetes (k3s) → orchestration, scaling, failover

### Networking

* Traefik → reverse proxy, ingress, TLS

### Observability

* Prometheus → metrics
* Grafana → dashboards
* Loki (optional) → centralized logs

### Automation

* n8n → workflows (alerts, backup, recovery)

### Data & Storage

* PostgreSQL (replication / HA patterns)
* MinIO / S3 → object storage and backups

### CI/CD

* GitHub Actions preferred
* Pipeline must validate infrastructure and deployment assets before apply
* CI/CD must support safe iteration and reproducibility

---

## 🏗️ Architecture

Clients → Traefik → Kubernetes Cluster

Namespaces:

* app:

  * web applications
  * APIs
  * internal dashboard
* infra:

  * PostgreSQL
  * MinIO
  * Prometheus + Grafana
  * n8n

---

## ⚙️ Infrastructure Layout

Target architecture:

* 1 control plane node
* 3 Kubernetes worker nodes
* 2 PostgreSQL nodes
* 1 load balancer
* 1 ops node (monitoring + automation)

---

## 🔁 Automation Workflow

### Bootstrap

A script must:

* collect user inputs:

  * number of nodes
  * machine types
  * domain
  * services to deploy
* generate dynamically:

  * Terraform variables
  * Ansible inventory
  * Kubernetes or Helm configuration
* execute:

  * terraform apply
  * ansible-playbook
  * kubectl apply

### Destroy

* terraform destroy

Infrastructure must be:

* reproducible
* disposable
* cost-efficient
* version-controlled

---

## 📊 Use Cases

* load testing
* failover simulation
* service recovery
* backup / restore validation
* CI/CD validation
* multi-environment experiments

---

## 🧩 Repository Structure

project-root/

* terraform/
* ansible/
* k8s/
* scripts/
* dashboard/
* docs/
* .github/workflows/

---

## 🌿 Git Workflow Rules

Git discipline is mandatory.

### Branching Strategy

* main → stable and validated state
* dev → primary integration branch
* feature/* → new features
* infra/* → infrastructure changes
* fix/* → bug fixes
* docs/* → documentation only

### Commit Rules

* commits must be atomic and explicit
* one logical change per commit
* avoid mixing infra, app, and docs in the same commit unless strictly necessary
* commit messages should clearly describe intent

Preferred commit style examples:

* feat(terraform): add load balancer module
* fix(ansible): correct PostgreSQL replication task
* chore(k8s): reorganize namespace manifests
* docs(security): add backup recovery procedure

### Pull Request Rules

* every significant change should be reviewed before merge
* pull requests must include:

  * goal
  * impacted components
  * risks
  * validation performed
* infrastructure changes must describe rollback strategy

### Forbidden Git Actions

* never commit secrets
* never commit generated sensitive files
* never force push to main
* never bypass review for critical infra or security changes

---

## 🔄 CI/CD Requirements

CI/CD is part of the architecture and must be treated as production infrastructure.

### CI Goals

The pipeline must automatically validate:

* Terraform formatting and validation
* Ansible syntax and linting
* Kubernetes manifest validity
* YAML formatting and consistency
* basic shell script quality where relevant

### CD Goals

Deployment automation must:

* be reproducible
* minimize manual steps
* support rollback thinking
* avoid unsafe direct changes on running systems

### Preferred CI/CD Stages

1. lint
2. validate
3. security checks
4. plan
5. deploy (only when explicitly allowed)

### CI/CD Safety Rules

* deployment to stable environments must not happen from unreviewed branches
* destructive operations must require explicit intent
* pipeline outputs must be readable and useful for debugging
* failed validation must block deployment steps

### Infrastructure Validation Expectations

Before any apply or deploy:

* terraform fmt and validate must pass
* ansible syntax checks and lint must pass
* Kubernetes configs must be validated
* secrets must not be embedded in manifests or repository files

---

## 🔧 Engineering Principles

* everything must be reproducible
* no manual configuration drift
* no hardcoded sensitive values
* infrastructure must be modular
* systems must be production-like
* documentation must evolve with the code

---

## 🔐 Security Requirements (MANDATORY)

Security is a core part of the architecture.

### Access Control

* enforce least privilege
* use dedicated service accounts
* separate admin, ops, and application roles
* protect admin interfaces

### Secrets Management

* never store secrets in Git
* use encrypted or external secret mechanisms where possible
* restrict access to sensitive values
* rotate credentials regularly

### Kubernetes Security

* enforce workload security standards
* run containers as non-root whenever possible
* avoid privileged containers
* avoid unnecessary host access

### Network Security

* only Traefik is public
* internal services must remain private
* use firewall rules and network segmentation
* enforce TLS everywhere relevant

### Node Hardening

* use minimal systems
* keep nodes updated
* protect kubeconfig and administrative credentials

### Supply Chain Security

* use trusted base images
* pin versions
* scan images and dependencies
* review third-party manifests before use

### Monitoring & Audit

* monitor anomalies, failures, and certificate expiration
* track important infrastructure events
* log operationally relevant actions

### Backup & Recovery

* backups must be encrypted where relevant
* restoration must be tested
* recovery procedures must be documented

---

## 🧪 Validation

Before applying changes:

* validate Terraform
* lint and check Ansible
* validate Kubernetes configurations
* ensure CI checks are green
* document important architectural changes

---

## 🚀 Codex Behavior Rules

Codex must:

* respect the full architecture
* prioritize automation over manual operations
* preserve Git hygiene
* preserve CI/CD consistency
* avoid shortcuts
* maintain production-level quality
* not introduce unreviewed destructive automation
* update documentation when architecture changes

When making changes, Codex should:

* prefer small focused commits
* suggest pipeline updates when new tooling is introduced
* keep branch intent clear
* explain deployment impact for infrastructure modifications

---

## ❌ Forbidden Actions

* hardcoding secrets
* bypassing security controls
* manual production-like drift
* exposing internal services publicly
* using privileged containers without justification
* pushing unvalidated infra changes directly to stable branches
* disabling CI checks to make a change pass

---

## 🎯 Final Objective

Build a realistic, secure, scalable, and automated DevOps infrastructure capable of:

* simulating production systems
* being deployed on demand
* being tested under stress and failure
* demonstrating advanced DevOps skills
* showcasing strong Git, CI/CD, and operational discipline
