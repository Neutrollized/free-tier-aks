output "connection_string" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${azurerm_resource_group.aks.name} --overwrite-existing"
}

output "install_cilium_cmd" {
  value = "cilium install --version ${var.cilium_version} --context ${azurerm_kubernetes_cluster.aks.name} --set cluster.name='${azurerm_kubernetes_cluster.aks.name}' --set cluster.id=${var.cluster_id} --set azure.resourceGroup='${azurerm_resource_group.aks.name}' --set ipam.operator.clusterPoolIPv4PodCIDRList='{${var.pods_ipv4_cidr_block[0]}}'"
}

output "vnet_id" {
  value = azurerm_virtual_network.aks.id
}
