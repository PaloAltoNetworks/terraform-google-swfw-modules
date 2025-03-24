locals {
  delicensing_enabled = var.delicensing_cloud_function_config != null ? true : false
  name_prefix   = local.delicensing_enabled ? var.delicensing_cloud_function_config.name_prefix : ""
  function_name = local.delicensing_enabled ? var.delicensing_cloud_function_config.function_name : ""
  delicensing_cfn = {
    panorama_address        = local.delicensing_enabled ? var.delicensing_cloud_function_config.panorama_address : null
    panorama2_address       = local.delicensing_enabled ? var.delicensing_cloud_function_config.panorama2_address : null
    function_name           = "${local.name_prefix}${local.function_name}-${random_id.postfix.hex}"
    bucket_name             = "${local.name_prefix}${local.function_name}-${random_id.postfix.hex}"
    source_dir              = "${path.module}/src"
    zip_file_name           = local.function_name
    runtime_sa_account_id   = "${local.name_prefix}${local.function_name}-sa-${random_id.postfix.hex}"
    runtime_sa_display_name = "Delicensing Cloud Function runtime SA"
    runtime_sa_roles = [
      "roles/secretmanager.secretAccessor",
      "roles/compute.viewer",
    ]
    topic_name         = "${local.name_prefix}${local.function_name}_topic-${random_id.postfix.hex}"
    log_sink_name      = "${local.name_prefix}${local.function_name}_logsink-${random_id.postfix.hex}"
    entry_point        = "autoscale_delete_event"
    description        = "Cloud Function to delicense firewalls in Panorama on scale-in events"
    subscription_name  = "${local.name_prefix}${local.function_name}_subscription"
    secret_name        = "${local.name_prefix}${local.function_name}_pano_creds-${random_id.postfix.hex}"
    vpc_connector_name = "${local.name_prefix}${local.function_name}-${random_id.postfix.hex}"
  }
}