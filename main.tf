terraform {
  backend "s3" {}

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.39"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ─────────────────────────────────────────────
# PROVIDERS
# ─────────────────────────────────────────────
provider "hcloud" {
  token = var.MY_TOKEN
}

provider "cloudflare" {
  api_token = var.CLOUDFLARE_API_TOKEN
}

# ─────────────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────────────
variable "MY_TOKEN" {
  type      = string
  sensitive = true
}

variable "MY_SSH_KEY" {
  type      = string
  sensitive = true
}

variable "CLOUDFLARE_API_TOKEN" {
  type      = string
  sensitive = true
}

variable "CLOUDFLARE_ZONE_ID" {
  type = string
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "certbot_email" {
  type    = string
  default = ""
}

variable "certbot_staging" {
  type    = bool
  default = false
}

variable "server_name" {
  type    = string
  default = "server"
}

variable "server_type" {
  type    = string
  default = "cx23"
}

variable "server_location" {
  type    = string
  default = "nbg1"
}

variable "admin_user" {
  type    = string
  default = "ops"
}

variable "ssh_port" {
  type    = number
  default = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port < 65536
    error_message = "ssh_port doit etre un port TCP valide."
  }
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["127.0.0.1/32"]
}

# ─────────────────────────────────────────────
# FIREWALL
# ─────────────────────────────────────────────
resource "hcloud_firewall" "my_firewall" {
  name = "standard-firewall"

  # SSH restreint à ton IP uniquement (IPv4 + IPv6 personnelle si dispo)
  # CORRECTION : "::/0" retiré → tout IPv6 ne peut plus accéder au SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = tostring(var.ssh_port)
    source_ips = var.ssh_allowed_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# ─────────────────────────────────────────────
# CLÉ SSH
# ─────────────────────────────────────────────
resource "hcloud_ssh_key" "default" {
  name       = "my-ssh-key"
  public_key = var.MY_SSH_KEY
}

# ─────────────────────────────────────────────
# SERVEUR
# ─────────────────────────────────────────────
resource "hcloud_server" "example" {
  name         = var.server_name
  image        = "ubuntu-22.04"
  server_type  = var.server_type
  location     = var.server_location
  ssh_keys     = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.my_firewall.id]

  user_data = <<-EOT
    #cloud-config
    users:
      - name: ${var.admin_user}
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${hcloud_ssh_key.default.public_key}

    disable_root: true
    ssh_pwauth: false
    package_update: true
    package_upgrade: true

    bootcmd:
      - mkdir -p /etc/ssh/sshd_config.d

    write_files:
      - content: |
          Port ${var.ssh_port}
        path: /etc/ssh/sshd_config.d/custom-port.conf

    runcmd:
      - systemctl restart ssh
  EOT
}

# ─────────────────────────────────────────────
# DNS CLOUDFLARE
# ─────────────────────────────────────────────

# Domaine racine → site web (proxied = CDN + protection Cloudflare)
resource "cloudflare_record" "root_domain" {
  zone_id = var.CLOUDFLARE_ZONE_ID
  name    = "@"
  content = hcloud_server.example.ipv4_address
  type    = "A"
  ttl     = 1 # ttl=1 = "Auto" chez Cloudflare, correct pour proxied
  proxied = true
}

# Sous-domaine SSH → non-proxied obligatoire car Cloudflare ne proxy pas SSH
resource "cloudflare_record" "ssh_dns" {
  zone_id = var.CLOUDFLARE_ZONE_ID
  name    = "ssh"
  content = hcloud_server.example.ipv4_address
  type    = "A"
  ttl     = 300
  proxied = false
}

# Sous-domaine www
resource "cloudflare_record" "www" {
  zone_id = var.CLOUDFLARE_ZONE_ID
  name    = "www"
  content = hcloud_server.example.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = true
}

# ─────────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────────
output "server_ip" {
  description = "IP publique du serveur"
  value       = hcloud_server.example.ipv4_address
}

output "hostname" {
  description = "Hostname DNS du sous-domaine SSH"
  value       = try(cloudflare_record.ssh_dns.hostname, "N/A")
}

output "site_domain" {
  description = "Domaine principal du site"
  value       = var.domain_name
}
