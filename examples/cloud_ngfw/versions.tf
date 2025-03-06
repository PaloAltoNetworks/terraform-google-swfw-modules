terraform {
  required_version = ">= 1.3, < 2.0"
}

provider "google" {
  project               = var.project
  user_project_override = true
  billing_project       = var.project
}
