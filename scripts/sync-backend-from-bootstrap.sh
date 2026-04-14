#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[bootstrap-sync]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${ROOT_DIR}/terraform/bootstrap"
BACKEND_FILE="${ROOT_DIR}/backend.hcl"

command -v terraform >/dev/null || error "terraform n'est pas installe"
[ -d "${BOOTSTRAP_DIR}" ] || error "dossier bootstrap introuvable: ${BOOTSTRAP_DIR}"

log "Lecture des outputs Terraform bootstrap..."
if ! terraform_state_bucket="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw terraform_state_bucket 2>/dev/null)"; then
  error "Impossible de lire les outputs bootstrap. Lance d'abord: terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply"
fi

terraform_state_key="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw terraform_state_key)"
terraform_state_region="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw terraform_state_region)"
github_actions_role_arn="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_actions_role_arn)"
github_oidc_subject="$(terraform -chdir="${BOOTSTRAP_DIR}" output -raw github_oidc_subject)"

log "Generation de backend.hcl a la racine du projet..."
cat > "${BACKEND_FILE}" <<EOF
bucket       = "${terraform_state_bucket}"
key          = "${terraform_state_key}"
region       = "${terraform_state_region}"
encrypt      = true
use_lockfile = true
EOF
chmod 600 "${BACKEND_FILE}"

echo ""
log "backend.hcl genere avec succes: ${BACKEND_FILE}"
echo ""
echo "Valeurs a configurer dans GitHub Actions:"
echo "  Secret  AWS_ROLE_TO_ASSUME = ${github_actions_role_arn}"
echo "  Variable TF_STATE_BUCKET   = ${terraform_state_bucket}"
echo "  Variable TF_STATE_KEY      = ${terraform_state_key}"
echo "  Variable TF_STATE_REGION   = ${terraform_state_region}"
echo ""
warn "Sujet OIDC attendu par la trust policy:"
echo "  ${github_oidc_subject}"
echo ""
log "Prochaine etape conseillee:"
echo "  terraform init -backend-config=backend.hcl"
