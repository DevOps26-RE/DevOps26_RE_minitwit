data "digitalocean_ssh_key" "deployer" {
  name = var.ssh_key_name
}
