# Infrastructure config — change these to resize, move regions, or add nodes,
# then run `terraform apply`.

variable "do_token" {
  description = "DigitalOcean API token"
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key registered in DigitalOcean"
  type        = string
}

variable "region" {
  description = "DigitalOcean region"
  default     = "fra1"
}

variable "manager_size" {
  description = "Droplet size for swarm manager (ingress + web replicas)"
  default     = "s-2vcpu-2gb"
}

variable "monitoring_size" {
  description = "Droplet size for monitoring node (Prometheus, Loki, Grafana)"
  default     = "s-1vcpu-2gb"
}

variable "db_size" {
  description = "Droplet size for database node"
  default     = "s-1vcpu-1gb"
}
