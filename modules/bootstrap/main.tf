locals {
  bootstrap_filenames = var.bootstrap_files_dir != null ? { for f in fileset(var.bootstrap_files_dir, "**") : f => "${var.bootstrap_files_dir}/${f}" } : {}
  # invert var.files map 
  inverted_files     = { for k, v in var.files : v => k }
  inverted_filenames = merge(local.bootstrap_filenames, local.inverted_files)
  # invert local.filenames map
  filenames = { for k, v in local.inverted_filenames : v => k }
  folders   = length(var.folders) == 0 ? [""] : var.folders
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
resource "google_storage_bucket_object" "config_empty" {
  for_each = toset(local.folders)

  name    = each.value != "" ? "${each.value}/config/" : "config/"
  content = "config/"
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "content_empty" {
  for_each = toset(local.folders)

  name    = each.value != "" ? "${each.value}/content/" : "content/"
  content = "content/"
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "license_empty" {
  for_each = toset(local.folders)

  name    = each.value != "" ? "${each.value}/license/" : "license/"
  content = "license/"
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "software_empty" {
  for_each = toset(local.folders)

  name    = each.value != "" ? "${each.value}/software/" : "software/"
  content = "software/"
  bucket  = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "file" {
  for_each = local.filenames

  name   = each.value
  source = each.key
  bucket = google_storage_bucket.this.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_default_service_account
data "google_compute_default_service_account" "this" {}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam_member_remove
resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account != null ? var.service_account : data.google_compute_default_service_account.this.email}"
}