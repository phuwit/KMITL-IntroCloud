terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=7.20.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">=5.17.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}