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