# ─────────────────────────────────────────────
# GÉNÉRATION AUTOMATIQUE DE L'INVENTAIRE ANSIBLE
# Ajout à la fin de ton main.tf
# ─────────────────────────────────────────────

# Génère ./inventory/hosts.ini après chaque terraform apply
# Plus besoin de copier l'IP à la main
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory/hosts.ini.tpl", {
    ssh_host             = cloudflare_record.ssh_dns.hostname
    server_ip            = hcloud_server.example.ipv4_address
    ssh_port             = var.ssh_port
    ansible_user         = var.admin_user
    ssh_private_key_file = "~/.ssh/id_ed25519"
    public_domain        = var.domain_name
    public_www_domain    = "www.${var.domain_name}"
    certbot_email        = var.certbot_email
    certbot_staging      = var.certbot_staging
  })
  filename        = "${path.module}/inventory/hosts.ini"
  file_permission = "0644"
}
