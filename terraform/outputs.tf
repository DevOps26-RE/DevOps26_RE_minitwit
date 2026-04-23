output "manager_ip" {
  description = "Public IP of the swarm manager (ingress node)"
  value       = digitalocean_droplet.manager.ipv4_address
}

output "monitoring_ip" {
  description = "Public IP of the monitoring node"
  value       = digitalocean_droplet.monitoring.ipv4_address
}

output "db_private_ip" {
  description = "Private IP of the database node (VPC-only, used as DB_ADDR)"
  value       = digitalocean_droplet.db.ipv4_address_private
}

output "db_public_ip" {
  description = "Public IP of the database node (for initial Ansible provisioning)"
  value       = digitalocean_droplet.db.ipv4_address
}
