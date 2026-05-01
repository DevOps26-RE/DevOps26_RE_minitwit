# ==========================================================================
# Terraform Configuration for Minitwit - STAGE Environment
# ==========================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.30.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "my_ssh_key" {
  name = var.ssh_key_name
}

resource "digitalocean_tag" "minitwit_stage" {
  name = "minitwit-stage"
}

resource "digitalocean_vpc" "minitwit_vpc" {
  name     = "minitwit-stage-vpc"
  region   = "fra1"
  ip_range = "10.10.10.0/24"
}

# --- Manager 1 ---
resource "digitalocean_droplet" "manager1_stage" {
  image    = "ubuntu-22-04-x64"
  name     = "manager1-stage"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_stage.id]
}

# --- Manager 2 ---
resource "digitalocean_droplet" "manager2_stage" {
  image    = "ubuntu-22-04-x64"
  name     = "manager2-stage"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_stage.id]
}

# --- Swarm Leader / DB / Monitoring ---
resource "digitalocean_droplet" "db_stage" {
  image    = "ubuntu-22-04-x64"
  name     = "db-stage"
  region   = "fra1"
  size     = "s-2vcpu-2gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_stage.id]
}

resource "digitalocean_firewall" "minitwit_fw" {
  name = "minitwit-stage-firewall"
  tags = [digitalocean_tag.minitwit_stage.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "2377"
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "7946"
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "7946"
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }
  inbound_rule {
    protocol         = "udp"
    port_range       = "4789"
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "5432"
    source_addresses = [digitalocean_vpc.minitwit_vpc.ip_range]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# --- Generate Ansible Inventory ---
resource "local_file" "ansible_inventory" {
  content = <<EOT
[swarm_leaders]
db-stage ansible_host=${digitalocean_droplet.db_stage.ipv4_address}

[swarm_managers]
manager1-stage ansible_host=${digitalocean_droplet.manager1_stage.ipv4_address}
manager2-stage ansible_host=${digitalocean_droplet.manager2_stage.ipv4_address}

[all:vars]
ansible_user=root
EOT
  filename = "../../ansible/inventory_stage.ini"
}

resource "null_resource" "run_ansible_stage" { # null_resource is a TYPE does not create anything, just run commands
  depends_on = [
    digitalocean_droplet.db_stage,
    digitalocean_droplet.manager1_stage,
    digitalocean_droplet.manager2_stage,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = "sleep 30 && cd ${path.module}/../../ && ansible-playbook -i ansible/inventory_stage.ini ansible/site.yml"
  }
}

# --- Get Private IPs from VPC ---
resource "null_resource" "get_private_ips" {
  depends_on = [
    digitalocean_droplet.db_stage,
    digitalocean_droplet.manager1_stage,
    digitalocean_droplet.manager2_stage
  ]
}

# --- Generate .env file with dynamic IPs ---
resource "local_file" "env_file" {
  content = <<EOT
DIGITAL_OCEAN_TOKEN=${var.do_token}
SSH_KEY_NAME=${var.ssh_key_name}
CONFIG_VER=1.0
TLS_ENABLED=false
DOCKER_IMAGE=runtimeerroritu/minitwit:latest
PROM_IMAGE=runtimeerroritu/minitwit-prometheus:latest
DB_ADDR=${digitalocean_droplet.db_stage.networks[1].ipv4_address}
DOMAIN=${var.domain}
MANAGER1_IP=${digitalocean_droplet.manager1_stage.ipv4_address}
MANAGER2_IP=${digitalocean_droplet.manager2_stage.ipv4_address}
PROM_URL=https://${var.domain}/prometheus
GRAFANA_URL=https://${var.domain}/grafana/
ENTRYPOINT=web
EOT
  filename = "../../.env_staging"
  
  depends_on = [
    digitalocean_droplet.db_stage,
    digitalocean_droplet.manager1_stage,
    digitalocean_droplet.manager2_stage
  ]
}
