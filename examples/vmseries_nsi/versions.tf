terraform {
  required_version = ">= 1.3, < 2.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.15"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.15"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}
