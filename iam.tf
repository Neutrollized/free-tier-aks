###----------------------------------------
# Cluster and Kubelet Identity
#------------------------------------------
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-user"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_role_assignment" "aks" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-kubelet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_role_assignment" "kubelet" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
}


###----------------------------------------
# Workload Identity user
#------------------------------------------
resource "azurerm_user_assigned_identity" "wi_user" {
  count               = var.enable_workload_identity ? 1 : 0
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-wi-user"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}
