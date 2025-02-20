variable "service_account_id" {
  description =  "The ID of the created IAM account, unique string per project."
  type    = string
}

variable "display_name" {
  description = "The display name for the service account"
  type = string
  default = "Palo Alto Networks Firewall Service Account"
}

variable "roles" {
  description = "List of IAM role names, such as [\"roles/compute.viewer\"] or [\"project/A/roles/B\"]. The default list is suitable for Palo Alto Networks Firewall to run and publish custom metrics to GCP Stackdriver."
  default = [
    "roles/compute.networkViewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/viewer", # to reach a bootstrap bucket (project's storage.buckets.list with bucket's roles/storage.objectViewer insufficient)
    # per https://docs.paloaltonetworks.com/vm-series/9-1/vm-series-deployment/set-up-the-vm-series-firewall-on-google-cloud-platform/deploy-vm-series-on-gcp/enable-google-stackdriver-monitoring-on-the-vm-series-firewall.html
    "roles/stackdriver.accounts.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ]
  type = set(string)
}

variable "project_id" {
  description = "ID of a project in which the service account will be created."
  type        = string
}