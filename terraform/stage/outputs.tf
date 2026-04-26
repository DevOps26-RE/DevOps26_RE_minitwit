# Output the public IP addresses for Ansible
output "manager1_ip" {
  value = digitalocean_droplet.manager1_stage.ipv4_address
}

output "manager2_ip" {
  value = digitalocean_droplet.manager2_stage.ipv4_address
}

output "db_ip" {
  value = digitalocean_droplet.db_stage.ipv4_address
}