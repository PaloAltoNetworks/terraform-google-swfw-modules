# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/app_engine_default_service_account
data "google_compute_default_service_account" "main" {
  project = var.project_id
}

# Instance template
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template
resource "google_compute_instance_template" "main" {
  project          = var.project_id
  name_prefix      = var.name
  machine_type     = var.machine_type
  min_cpu_platform = var.min_cpu_platform
  tags             = var.tags
  metadata         = var.metadata
  can_ip_forward   = true

  service_account {
    scopes = var.scopes
    email  = var.service_account_email
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces

    content {
      subnetwork = network_interface.value.subnetwork

      dynamic "access_config" {
        for_each = coalesce(network_interface.value.create_public_ip, false) ? ["one"] : []
        content {}
      }
    }
  }

  disk {
    source_image = var.image
    disk_type    = var.disk_type
    auto_delete  = true
    boot         = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Zonal managed instance group and autoscaler
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group_manager
resource "google_compute_instance_group_manager" "zonal" {
  for_each = var.regional_mig ? {} : var.zones

  project            = var.project_id
  name               = "${var.name}-${each.value}"
  base_instance_name = var.name
  target_pools       = var.target_pools
  zone               = each.value

  version {
    instance_template = google_compute_instance_template.main.id
  }

  lifecycle {
    ignore_changes = [
      version[0].name,
      version[1].name,
    ]
  }

  update_policy {
    type            = var.update_policy_type
    max_surge_fixed = 1
    minimal_action  = "REPLACE"
  }

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_autoscaler
resource "google_compute_autoscaler" "zonal" {
  for_each = var.regional_mig ? {} : var.zones

  project = var.project_id
  name    = "${var.name}-${each.value}"
  target  = google_compute_instance_group_manager.zonal[each.key].id
  zone    = each.value

  autoscaling_policy {
    min_replicas    = var.min_vmseries_replicas
    max_replicas    = var.max_vmseries_replicas
    cooldown_period = var.cooldown_period

    dynamic "metric" {
      for_each = var.autoscaler_metrics
      content {
        name   = metric.key
        type   = metric.value.type
        target = metric.value.target
      }
    }

    scale_in_control {
      time_window_sec = var.scale_in_control_time_window_sec
      max_scaled_in_replicas {
        fixed = var.scale_in_control_replicas_fixed
      }
    }
  }
}

# Regional managed instance group and autoscaler
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones
data "google_compute_zones" "main" {
  count = var.regional_mig ? 1 : 0

  project = var.project_id
  region  = var.region
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager
resource "google_compute_region_instance_group_manager" "regional" {
  count = var.regional_mig ? 1 : 0

  project            = var.project_id
  name               = var.name
  base_instance_name = var.name
  target_pools       = var.target_pools
  region             = var.region

  version {
    instance_template = google_compute_instance_template.main.id
  }

  update_policy {
    type            = var.update_policy_type
    max_surge_fixed = length(data.google_compute_zones.main[0])
    minimal_action  = "REPLACE"
  }

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_autoscaler
resource "google_compute_region_autoscaler" "regional" {
  count = var.regional_mig ? 1 : 0

  project = var.project_id
  name    = var.name
  target  = google_compute_region_instance_group_manager.regional[0].id
  region  = var.region

  autoscaling_policy {
    min_replicas    = var.min_vmseries_replicas
    max_replicas    = var.max_vmseries_replicas
    cooldown_period = var.cooldown_period

    dynamic "metric" {
      for_each = var.autoscaler_metrics
      content {
        name   = metric.key
        target = metric.value.target
        type   = metric.value.type
        filter = metric.value.filter
      }
    }

    scale_in_control {
      time_window_sec = var.scale_in_control_time_window_sec
      max_scaled_in_replicas {
        fixed = var.scale_in_control_replicas_fixed
      }
    }
  }
}

# Pub/Sub for Panorama Plugin
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic.html
resource "google_pubsub_topic" "main" {
  count = var.create_pubsub_topic ? 1 : 0

  project = var.project_id
  name    = "${var.name}-mig"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription
resource "google_pubsub_subscription" "main" {
  count = var.create_pubsub_topic ? 1 : 0

  project = var.project_id
  name    = "${var.name}-mig"
  topic   = google_pubsub_topic.main[0].id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription_iam
resource "google_pubsub_subscription_iam_member" "main" {
  count = var.create_pubsub_topic ? 1 : 0

  project      = var.project_id
  subscription = google_pubsub_subscription.main[0].id
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${coalesce(var.service_account_email, data.google_compute_default_service_account.main.email)}"
}

#---------------------------------------------------------------------------------
# The following resources are used for delicensing

resource "random_id" "postfix" {
  byte_length = 2
}

# Secret to store Panorama credentials.
# Credentials itself are set manually after secret store is created by Terraform.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
resource "google_secret_manager_secret" "delicensing_cfn_pano_creds" {
  count     = local.delicensing_enabled ? 1 : 0
  project   = var.project_id
  secret_id = local.delicensing_cfn.secret_name
  replication {
    auto {}
  }
}

# Create a log sink to match the delete of a VM from a Managed Instance group during the initial phase
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink
resource "google_logging_project_sink" "delicensing_cfn" {
  count                  = local.delicensing_enabled ? 1 : 0
  project                = var.project_id
  destination            = "pubsub.googleapis.com/${google_pubsub_topic.delicensing_cfn[0].id}"
  name                   = local.delicensing_cfn.log_sink_name
  filter                 = "protoPayload.requestMetadata.callerSuppliedUserAgent=\"GCE Managed Instance Group\" AND protoPayload.methodName=\"v1.compute.instances.delete\" AND protoPayload.response.progress=\"0\""
  unique_writer_identity = true
}

# Create a pub/sub topic for messaging log sink events
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic.html
resource "google_pubsub_topic" "delicensing_cfn" {
  count   = local.delicensing_enabled ? 1 : 0
  project = var.project_id
  name    = local.delicensing_cfn.topic_name
}

# Allow log router writer identity to publish to pub/sub
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam
resource "google_pubsub_topic_iam_member" "pubsub_sink_member" {
  count   = local.delicensing_enabled ? 1 : 0
  project = var.project_id
  topic   = local.delicensing_cfn.topic_name
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.delicensing_cfn[0].writer_identity
}

# VPC Connector required for Cloud Function to access local Panorama instance
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector
resource "google_vpc_access_connector" "delicensing_cfn" {
  count         = local.delicensing_enabled ? 1 : 0
  project       = var.project_id
  name          = local.delicensing_cfn.vpc_connector_name
  region        = var.region
  ip_cidr_range = var.delicensing_cloud_function_config.vpc_connector_cidr
  network       = var.delicensing_cloud_function_config.vpc_connector_network
}

# Cloud Function code storage bucket
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "delicensing_cfn" {
  count                       = local.delicensing_enabled ? 1 : 0
  project                     = var.project_id
  name                        = local.delicensing_cfn.bucket_name
  location                    = var.delicensing_cloud_function_config.bucket_location
  force_destroy               = true
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

data "archive_file" "delicensing_cfn" {
  count       = local.delicensing_enabled ? 1 : 0
  type        = "zip"
  source_dir  = local.delicensing_cfn.source_dir
  output_path = "/tmp/${local.delicensing_cfn.zip_file_name}.zip"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object
resource "google_storage_bucket_object" "delicensing_cfn" {
  count  = local.delicensing_enabled ? 1 : 0
  name   = "${local.delicensing_cfn.zip_file_name}.${lower(replace(data.archive_file.delicensing_cfn[0].output_base64sha256, "=", ""))}.zip"
  bucket = local.delicensing_cfn.bucket_name
  source = "/tmp/${local.delicensing_cfn.zip_file_name}.zip"

  depends_on = [
    google_storage_bucket.delicensing_cfn
  ]
}

# Cloud Function Service Account
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "delicensing_cfn" {
  count        = local.delicensing_enabled ? 1 : 0
  project      = var.project_id
  account_id   = local.delicensing_cfn.runtime_sa_account_id
  display_name = local.delicensing_cfn.runtime_sa_display_name
}

# Granting required roles to Cloud Function SA
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_member" "delicensing_cfn" {
  for_each = local.delicensing_enabled ? toset(local.delicensing_cfn.runtime_sa_roles) : []
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.delicensing_cfn[0].email}"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function
resource "google_cloudfunctions2_function" "delicensing_cfn" {
  count       = local.delicensing_enabled ? 1 : 0
  project     = var.project_id
  name        = local.delicensing_cfn.function_name
  description = local.delicensing_cfn.description
  location    = var.region
  build_config {
    runtime     = "python310"
    entry_point = local.delicensing_cfn.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.delicensing_cfn[0].name
        object = google_storage_bucket_object.delicensing_cfn[0].name
      }
    }
  }
  service_config {
    available_memory   = "256M"
    timeout_seconds    = 60
    max_instance_count = 5
    environment_variables = {
      "PANORAMA_ADDRESS"  = local.delicensing_cfn.panorama_address
      "PANORAMA2_ADDRESS" = local.delicensing_cfn.panorama2_address
      "PROJECT_ID"        = var.project_id
      "SECRET_NAME"       = google_secret_manager_secret.delicensing_cfn_pano_creds[0].secret_id
    }
    service_account_email          = google_service_account.delicensing_cfn[0].email
    vpc_connector                  = google_vpc_access_connector.delicensing_cfn[0].self_link
    vpc_connector_egress_settings  = "PRIVATE_RANGES_ONLY"
    all_traffic_on_latest_revision = true
  }
  event_trigger {
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.delicensing_cfn[0].id
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
    trigger_region = var.region
  }
  depends_on = [google_storage_bucket_object.delicensing_cfn]
}

# Allow Cloud Function invocation from pub/sub
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_member" "delicensing_cfn_invoker" {
  count   = local.delicensing_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${data.google_compute_default_service_account.main.email}"
}

