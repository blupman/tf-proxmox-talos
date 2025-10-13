output "talosconfig" {
  value     = data.talos_client_configuration.talos.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.talos.kubeconfig_raw
  sensitive = true
}

output "controllers" {
  value = join(",", [for node in local.controller_nodes : node.address])
}

output "workers" {
  value = join(",", [for node in local.worker_nodes : node.address])
}
output "csi_token_id" {
  value = "${proxmox_virtual_environment_user.kubernetes_csi.user_id}!CSItf"
}
output "csi_token_secret" {
  value = split("=", proxmox_virtual_environment_user_token.kubernetes_csi.value)[1]
  sensitive = true
}
