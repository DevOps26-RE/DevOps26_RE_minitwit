resource "digitalocean_vpc" "minitwit" {
  name     = "minitwit-vpc-${terraform.workspace}"
  region   = var.region
  ip_range = "10.116.0.0/24"
}
