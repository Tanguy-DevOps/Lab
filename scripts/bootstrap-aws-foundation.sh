#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[bootstrap]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${ROOT_DIR}/terraform/bootstrap"
TFVARS_FILE="${BOOTSTRAP_DIR}/terraform.tfvars"
PLAN_FILE="${BOOTSTRAP_DIR}/tfplan"

require_file_permissions() {
  local file="$1"
  local expected="$2"
  local current

  current=$(stat -c "%a" "$file")
  [ "$current" = "$expected" ] || error "$file doit avoir les permissions $expected (actuel: $current)"
}

confirm_apply() {
  local answer
  echo ""
  warn "Cette commande va creer ou modifier de l'infrastructure AWS persistante."
  read -r -p "Continuer avec 'terraform apply' ? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) error "Bootstrap annule par l'utilisateur" ;;
  esac
}

log "Verification des pre-requis..."
command -v terraform >/dev/null || error "terraform n'est pas installe"
[ -f "${BOOTSTRAP_DIR}/main.tf" ] || error "dossier bootstrap introuvable: ${BOOTSTRAP_DIR}"
[ -f "${TFVARS_FILE}" ] || error "terraform/bootstrap/terraform.tfvars introuvable. Cree-le avec: cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars"

require_file_permissions "${TFVARS_FILE}" "600"
grep -Eq '^[[:space:]]*terraform_state_bucket[[:space:]]*=' "${TFVARS_FILE}" || error "terraform_state_bucket est requis dans terraform/bootstrap/terraform.tfvars"

if grep -Eq '^[[:space:]]*enable_vault_prerequisites[[:space:]]*=[[:space:]]*true([[:space:]]|$)' "${TFVARS_FILE}"; then
  grep -Eq '^[[:space:]]*vault_snapshot_bucket[[:space:]]*=' "${TFVARS_FILE}" || error "vault_snapshot_bucket est requis quand enable_vault_prerequisites=true"
fi

log "Validation Terraform bootstrap..."
(
  cd "${BOOTSTRAP_DIR}"
  terraform fmt -check *.tf
)
terraform -chdir="${BOOTSTRAP_DIR}" init -input=false
terraform -chdir="${BOOTSTRAP_DIR}" validate

log "Plan Terraform bootstrap (non-interactif)..."
terraform -chdir="${BOOTSTRAP_DIR}" plan -input=false -var-file="${TFVARS_FILE}" -out="${PLAN_FILE}"

confirm_apply

log "Application Terraform bootstrap..."
terraform -chdir="${BOOTSTRAP_DIR}" apply "${PLAN_FILE}"

log "Synchronisation du backend Terraform racine..."
"${ROOT_DIR}/scripts/sync-backend-from-bootstrap.sh"

echo ""
log "Bootstrap termine."
echo "Prochaine etape:"
echo "  terraform init -reconfigure -backend-config=backend.hcl"
