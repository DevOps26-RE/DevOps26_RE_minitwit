resource "digitalocean_droplet" "manager" {
  name     = "swarm-manager-${terraform.workspace}"
  region   = var.region
  size     = var.manager_size
  image    = "ubuntu-22-04-x64"
  vpc_uuid = digitalocean_vpc.minitwit.id
  ssh_keys = [data.digitalocean_ssh_key.deployer.id]
}

resource "digitalocean_droplet" "monitoring" {
  name     = "swarm-monitoring-${terraform.workspace}"
  region   = var.region
  size     = var.monitoring_size
  image    = "ubuntu-22-04-x64"
  vpc_uuid = digitalocean_vpc.minitwit.id
  ssh_keys = [data.digitalocean_ssh_key.deployer.id]
}

resource "digitalocean_droplet" "db" {
  name     = "minitwit-db-${terraform.workspace}"
  region   = var.region
  size     = var.db_size
  image    = "ubuntu-22-04-x64"
  vpc_uuid = digitalocean_vpc.minitwit.id
  ssh_keys = [data.digitalocean_ssh_key.deployer.id]
}
