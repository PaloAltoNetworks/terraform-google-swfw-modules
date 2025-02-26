# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "this" {
  account_id   = var.service_account_id
  display_name = var.display_name
  project      = var.project_id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_member-1
resource "google_project_iam_member" "this" {
  for_each = var.roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}