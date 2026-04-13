#!/bin/bash
set -euo pipefail  # Stoppe le script dès qu'une commande échoue

# ─────────────────────────────────────────────
# COULEURS
# ─────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[deploy]${NC} $1"; }
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

confirm_apply() {
  local answer

  echo ""
  warn "Cette commande va creer ou modifier de l'infrastructure reelle."
  read -r -p "Continuer avec 'terraform apply' ? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      error "Deploiement annule par l'utilisateur"
      ;;
  esac
}

# ─────────────────────────────────────────────
# VÉRIFICATIONS PRÉALABLES
# ─────────────────────────────────────────────
log "Vérification des outils nécessaires..."
command -v terraform        || error "terraform n'est pas installé"
command -v ansible-playbook || error "ansible-playbook n'est pas installé"
command -v ansible-galaxy   || error "ansible-galaxy n'est pas installé"
command -v ssh-keyscan      || error "ssh-keyscan n'est pas installé"
command -v nc               || error "nc (netcat) n'est pas installé"

[ -f "main.tf" ]                 || error "main.tf introuvable — lance ce script depuis la racine du projet"
[ -f "setup_web.yml" ]           || error "setup_web.yml introuvable"
[ -f "requirements.yml" ]        || error "requirements.yml introuvable"
[ -f "inventory/hosts.ini.tpl" ] || error "inventory/hosts.ini.tpl introuvable"
[ -f "terraform.tfvars" ]        || error "terraform.tfvars introuvable — cree-le a partir de terraform.tfvars.example"
[ -f "backend.hcl" ]             || error "backend.hcl introuvable — cree-le a partir de backend.hcl.example"

require_file_permissions "terraform.tfvars" "600"

log "Validation des variables sensibles..."
for required_key in MY_TOKEN MY_SSH_KEY CLOUDFLARE_API_TOKEN CLOUDFLARE_ZONE_ID domain_name certbot_email ssh_allowed_cidrs; do
  grep -Eq "^${required_key}[[:space:]]*=" terraform.tfvars \
    || error "La variable ${required_key} est absente de terraform.tfvars"
done

log "Verification Terraform..."
terraform fmt
terraform fmt -check

# ─────────────────────────────────────────────
# 1. TERRAFORM
# ─────────────────────────────────────────────
log "Initialisation Terraform..."
terraform init -upgrade -backend-config=backend.hcl
terraform validate

confirm_apply

log "Plan Terraform..."
terraform plan -out=tfplan

log "Application Terraform (création serveur + DNS + inventaire)..."
terraform apply tfplan

[ -f "inventory/hosts.ini" ] || error "inventory/hosts.ini n'a pas été généré par Terraform"
log "Inventaire Ansible généré :"
cat inventory/hosts.ini

# ─────────────────────────────────────────────
# 2. MISE À JOUR DE KNOWN_HOSTS
# Supprime l'ancienne clé SSH si le serveur a été recréé
# et enregistre la nouvelle — nécessaire avec host_key_checking = True
# ─────────────────────────────────────────────
SERVER_IP=$(terraform output -raw server_ip)
SITE_DOMAIN=$(terraform output -raw site_domain)
SSH_PORT=$(awk -F= '/^ansible_port=/{print $2}' inventory/hosts.ini)
SSH_HOST=$(awk 'NR==2 {print $1}' inventory/hosts.ini)
SSH_USER=$(awk -F= '/^ansible_user=/{print $2}' inventory/hosts.ini)
log "Mise à jour de known_hosts pour $SERVER_IP..."
ssh-keygen -R "$SERVER_IP" 2>/dev/null || true
ssh-keygen -R "$SSH_HOST" 2>/dev/null || true

log "Attente de l'ouverture du port SSH (${SSH_PORT})..."
timeout 60 bash -c "until nc -z $SERVER_IP $SSH_PORT; do sleep 2; done" \
  || error "Le port SSH ${SSH_PORT} n'est pas accessible après 60s"

ssh-keyscan -p "$SSH_PORT" -H "$SERVER_IP" >> ~/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -p "$SSH_PORT" -H "$SSH_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true
log "Clé SSH enregistrée dans known_hosts"

# ─────────────────────────────────────────────
# 3. ANSIBLE — COLLECTIONS
# ─────────────────────────────────────────────
log "Installation des collections Ansible..."
ansible-galaxy collection install -r requirements.yml

log "Verification Ansible..."
ansible-playbook --syntax-check setup_web.yml

# ─────────────────────────────────────────────
# 4. ATTENTE PROPAGATION DNS (optionnel mais utile)
# ─────────────────────────────────────────────
warn "Attente 15s pour la propagation DNS Cloudflare..."
sleep 15

# ─────────────────────────────────────────────
# 5. ANSIBLE — PLAYBOOK
# ─────────────────────────────────────────────
log "Lancement du playbook Ansible..."
ansible-playbook setup_web.yml

# ─────────────────────────────────────────────
# RÉSULTAT
# ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}────────────────────────────────────────${NC}"
echo -e "${GREEN}  Déploiement terminé avec succès !${NC}"
echo -e "${GREEN}────────────────────────────────────────${NC}"
echo -e "  IP serveur  : ${YELLOW}${SERVER_IP}${NC}"
echo -e "  Site web    : ${YELLOW}https://${SITE_DOMAIN}${NC}"
echo -e "  SSH         : ${YELLOW}ssh -p ${SSH_PORT} ${SSH_USER}@${SERVER_IP}${NC}"
echo -e "${GREEN}────────────────────────────────────────${NC}"
