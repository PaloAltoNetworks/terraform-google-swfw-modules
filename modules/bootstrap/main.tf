locals {
  bootstrap_config_filenames   = var.bootstrap_files_dir != null ? { for file in fileset("${var.bootstrap_files_dir}/config", "**") : file => "${var.bootstrap_files_dir}/config/${file}" } : {}
  bootstrap_content_filenames  = var.bootstrap_files_dir != null ? { for file in fileset("${var.bootstrap_files_dir}/content", "**") : file => "${var.bootstrap_files_dir}/content/${file}" } : {}
  bootstrap_software_filenames = var.bootstrap_files_dir != null ? { for file in fileset("${var.bootstrap_files_dir}/software", "**") : file => "${var.bootstrap_files_dir}/software/${file}" } : {}
  bootstrap_license_filenames  = var.bootstrap_files_dir != null ? { for file in fileset("${var.bootstrap_files_dir}/license", "**") : file => "${var.bootstrap_files_dir}/license/${file}" } : {}
}

# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "randomstring" {
  length    = 10
  min_lower = 10
  special   = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "this" {
  name                        = join("", [var.name_prefix, random_string.randomstring.result])
  force_destroy               = true
  uniform_bucket_level_access = true
  location                    = var.location

  versioning {
    enabled = true
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "config_directory" {
  for_each = local.bootstrap_config_filenames != {} ? local.bootstrap_config_filenames : { "empty" : " " }

  name    = each.value != " " ? "/config/${each.key}" : "config/"
  source  = each.value != " " ? each.value : null
  content = each.value != " " ? null : " "
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "content_directory" {
  for_each = local.bootstrap_content_filenames != {} ? local.bootstrap_content_filenames : { "empty" : " " }

  name    = each.value != " " ? "/content/${each.key}" : "content/"
  source  = each.value != " " ? each.value : null
  content = each.value != " " ? null : " "
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "license_directory" {
  for_each = local.bootstrap_license_filenames != {} ? local.bootstrap_license_filenames : { "empty" : " " }

  name    = each.value != " " ? "/license/${each.key}" : "license/"
  source  = each.value != " " ? each.value : null
  content = each.value != " " ? null : " "
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "software_directory" {
  for_each = local.bootstrap_software_filenames != {} ? local.bootstrap_software_filenames : { "empty" : " " }

  name    = each.value != " " ? "/software/${each.key}" : "software/"
  source  = each.value != " " ? each.value : null
  content = each.value != " " ? null : " "
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_default_service_account
data "google_compute_default_service_account" "this" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam#google_storage_bucket_iam_member-1
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account != null ? var.service_account : data.google_compute_default_service_account.this.email}"
}