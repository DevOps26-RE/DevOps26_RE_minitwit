# Define the DigitalOcean API token
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

# Define the SSH key name registered in DigitalOcean
variable "ssh_key_name" {
  description = "Name of the SSH key in DigitalOcean"
  type        = string
}

variable "manager_count" {
  description = "Number of additional manager nodes (db_stage is always the swarm leader, so total managers = manager_count + 1, which must be odd)"
  type        = number
  default     = 2

  validation {
    condition     = var.manager_count % 2 == 0 && var.manager_count >= 2
    error_message = "manager_count must be an even number >= 2 (e.g. 2, 4, 6) so that total managers including db_stage is odd."
  }
}