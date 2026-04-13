#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[destroy]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

require_file_permissions() {
  local file="$1"
  local expected="$2"
  local current

  [ -f "$file" ] || return 0
  current=$(stat -c "%a" "$file")
  [ "$current" = "$expected" ] || error "$file doit avoir les permissions $expected (actuel: $current)"
}

confirm_destroy() {
  local answer

  echo ""
  warn "Cette commande va supprimer l'infrastructure geree par Terraform."
  warn "Les ressources Cloudflare, Hetzner et l'inventaire local seront detruits."
  read -r -p "Tape 'destroy' pour confirmer: " answer
  [ "$answer" = "destroy" ] || error "Destruction annulee par l'utilisateur"
}

log "Verification des outils necessaires..."
command -v terraform || error "terraform n'est pas installe"

[ -f "main.tf" ] || error "main.tf introuvable — lance ce script depuis la racine du projet"
[ -f "terraform.tfvars" ] || error "terraform.tfvars introuvable"
[ -f "backend.hcl" ] || error "backend.hcl introuvable — cree-le a partir de backend.hcl.example"

require_file_permissions "terraform.tfvars" "600"

log "Verification Terraform..."
terraform fmt -check
terraform init -upgrade -backend-config=backend.hcl
terraform validate

confirm_destroy

log "Destruction de l'infrastructure..."
terraform destroy

echo ""
echo -e "${GREEN}────────────────────────────────────────${NC}"
echo -e "${GREEN}  Destruction terminee${NC}"
echo -e "${GREEN}────────────────────────────────────────${NC}"
