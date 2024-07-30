output "connection_string" {
  value       = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${azurerm_resource_group.aks.name} --overwrite-existing"
  description = "CLI command for obtaining Kubernetes credentials for the AKS cluster."
}

output "install_cilium_cmd" {
  value       = var.enable_ebpf_data_plane ? "N/A - Cilium already enabled" : "cilium install --version ${var.cilium_version} --context ${azurerm_kubernetes_cluster.aks.name} --set cluster.name='${azurerm_kubernetes_cluster.aks.name}' --set cluster.id=${var.cluster_id} --set azure.resourceGroup='${azurerm_resource_group.aks.name}' --set ipam.operator.clusterPoolIPv4PodCIDRList='{${var.pods_ipv4_cidr_block[0]}}'"
  description = "Cilium CLI command for installing (OSS) Cilium."
}

output "vnet_id" {
  value       = azurerm_virtual_network.aks.id
  description = "Azure VNet ID for use when performing network peering or VPNs."
}

output "azure_files_storage_account_rg_name" {
  value       = var.enable_static_azurefiles ? "${azurerm_resource_group.storacctrg[0].name}" : "N/A - Static Azure Files not deployed"
  description = "Name of Resource Group housing Storage Account"
}

output "azure_files_storage_account_name" {
  value       = var.enable_static_azurefiles ? "${azurerm_storage_account.mystoracct[0].name}" : "N/A - Static Azure Files not deployed"
  description = "Name of Azure Storage Account providing Azure Files"
}

output "azure_files_file_share_name" {
  value       = var.enable_static_azurefiles ? "${azurerm_storage_share.myfileshare[0].name}" : "N/A - Static Azure Files not deployed"
  description = "Name of Azure Files file share"
}
