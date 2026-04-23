terraform {
  backend "s3" {
    # NOTE: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env var names are required
    # by the Terraform S3-compatible backend even for non-AWS endpoints.
    # In CI, set these to your DO Spaces access/secret key values.
    endpoints = {
      s3 = "https://fra1.digitaloceanspaces.com"
    }
    bucket                      = "minitwit-tf-state"
    key                         = "minitwit.tfstate"
    region                      = "us-east-1" # required placeholder for S3 backend
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
