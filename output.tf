output "_connection_string" {
  value       = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${azurerm_resource_group.aks.name} --overwrite-existing"
  description = "CLI command for obtaining Kubernetes credentials for the AKS cluster."
}

output "_install_cilium_cmd" {
  value       = var.enable_ebpf_data_plane ? "N/A - Cilium already enabled" : "cilium install --version ${var.cilium_version} --context ${azurerm_kubernetes_cluster.aks.name} --set cluster.name='${azurerm_kubernetes_cluster.aks.name}' --set cluster.id=${var.cluster_id} --set azure.resourceGroup='${azurerm_resource_group.aks.name}' --set ipam.operator.clusterPoolIPv4PodCIDRList='{${var.pods_ipv4_cidr_block[0]}}'"
  description = "Cilium CLI command for installing (OSS) Cilium."
}

output "_vnet_id" {
  value       = azurerm_virtual_network.aks.id
  description = "Azure VNet ID for use when performing network peering or VPNs."
}

output "aks_workload_identity_user_client_id" {
  value       = var.enable_workload_identity ? "${azurerm_user_assigned_identity.wi_user[0].client_id}" : "N/A - Workload Identity not enabled"
  description = "Client ID of the WI user (required for k8s service account)"
}

output "aks_workload_identity_oidc_issuer_url" {
  value       = var.enable_workload_identity || var.enable_oidc_issuer ? "${azurerm_kubernetes_cluster.aks.oidc_issuer_url}" : "N/A - Workload Identity not enabled"
  description = "OIDC Issuer URL"
}
