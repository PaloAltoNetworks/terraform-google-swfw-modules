terraform {
  required_version = ">= 1.3, < 2.0"
  required_providers {
    null   = { version = "~> 3.1" }
    google = { version = ">= 4.54" }
  }
}
