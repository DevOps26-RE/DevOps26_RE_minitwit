# ==========================================================================
# Terraform Configuration for Minitwit - PRODUCTION Environment
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

resource "digitalocean_tag" "minitwit_prod" {
  name = "minitwit-prod"
}

resource "digitalocean_vpc" "minitwit_vpc" {
  name     = "minitwit-prod-vpc"
  region   = "fra1"
  ip_range = "10.10.10.0/24"
}

# --- Manager 1 ---
resource "digitalocean_droplet" "manager1_prod" {
  image    = "ubuntu-22-04-x64"
  name     = "manager1-prod"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_prod.id]
}

# --- Manager 2 ---
resource "digitalocean_droplet" "manager2_prod" {
  image    = "ubuntu-22-04-x64"
  name     = "manager2-prod"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_prod.id]
}

# --- Swarm Leader / DB / Monitoring ---
resource "digitalocean_droplet" "db_prod" {
  image    = "ubuntu-22-04-x64"
  name     = "db-prod"
  region   = "fra1"
  size     = "s-2vcpu-2gb"
  ssh_keys = [data.digitalocean_ssh_key.my_ssh_key.id]
  vpc_uuid = digitalocean_vpc.minitwit_vpc.id
  tags     = [digitalocean_tag.minitwit_prod.id]
}

resource "digitalocean_firewall" "minitwit_fw" {
  name = "minitwit-stage-firewall"
  tags = [digitalocean_tag.minitwit_prod.id]

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
  content  = <<EOT
[swarm_leaders]
db-prod ansible_host=${digitalocean_droplet.db_prod.ipv4_address}

[swarm_managers]
manager1-prod ansible_host=${digitalocean_droplet.manager1_prod.ipv4_address}
manager2-prod ansible_host=${digitalocean_droplet.manager2_prod.ipv4_address}

[all:vars]
ansible_user=root
EOT
  filename = "../../ansible/inventory_prod.ini"
}

resource "null_resource" "run_ansible_prod" { # null_resource is a TYPE does not create anything, just run commands
  depends_on = [
    digitalocean_droplet.db_prod,
    digitalocean_droplet.manager1_prod,
    digitalocean_droplet.manager2_prod,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      cd ${path.module}/../../ansible

      INVENTORY="inventory_prod.ini"
      FIRST_HOST_IP=$(awk -F'ansible_host=' '/ansible_host=/{print $2; exit}' "$INVENTORY")

      if [ -z "$FIRST_HOST_IP" ]; then
        echo "Could not extract a host IP from $INVENTORY"
        exit 1
      fi

      if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new root@"$FIRST_HOST_IP" true >/dev/null 2>&1; then
        ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i "$INVENTORY" -e stack_env_file=../.env site.yml
        exit $?
      fi

      KEY_FOUND=""
      for key in "$HOME"/.ssh/*; do
        [ -f "$key" ] || continue
        case "$key" in
          *.pub|*.crt|*.cert|*known_hosts*|*authorized_keys|*/config) continue ;;
        esac

        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$key" root@"$FIRST_HOST_IP" true >/dev/null 2>&1; then
          KEY_FOUND="$key"
          break
        fi
      done

      if [ -z "$KEY_FOUND" ]; then
        echo "No working SSH private key found for $FIRST_HOST_IP. Ensure the matching private key is in ~/.ssh or loaded in ssh-agent."
        exit 1
      fi

      echo "Using SSH key: $KEY_FOUND"
      ANSIBLE_CONFIG=./ansible.cfg ansible-playbook -i "$INVENTORY" --private-key "$KEY_FOUND" -e stack_env_file=../.env site.yml
    EOT
  }
}

# --- Get Private IPs from VPC ---
resource "null_resource" "get_private_ips" {
  depends_on = [
    digitalocean_droplet.db_prod,
    digitalocean_droplet.manager1_prod,
    digitalocean_droplet.manager2_prod
  ]
}

# --- Generate .env file with dynamic IPs ---
resource "local_file" "env_file" {
  content  = <<EOT
DIGITAL_OCEAN_TOKEN=${var.do_token}
SSH_KEY_NAME=${var.ssh_key_name}
CONFIG_VER=1.0
TLS_ENABLED=false
DOCKER_IMAGE=runtimeerroritu/minitwit:latest
PROM_IMAGE=runtimeerroritu/minitwit-prometheus:latest
DB_ADDR=${digitalocean_droplet.db_prod.ipv4_address_private}

# Use nip.io to create a magic domain for the staging environment using the Public IP
DOMAIN=${digitalocean_droplet.manager1_prod.ipv4_address}.nip.io

MANAGER1_IP=${digitalocean_droplet.manager1_prod.ipv4_address}
MANAGER2_IP=${digitalocean_droplet.manager2_prod.ipv4_address}

# Update URLs to use the new nip.io domain
PROM_URL=http://${digitalocean_droplet.manager1_prod.ipv4_address}.nip.io/prometheus
GRAFANA_URL=http://${digitalocean_droplet.manager1_prod.ipv4_address}.nip.io/grafana/
ENTRYPOINT=web
EOT
  filename = "../../.env"

  depends_on = [
    digitalocean_droplet.db_prod,
    digitalocean_droplet.manager1_prod,
    digitalocean_droplet.manager2_prod
  ]
}