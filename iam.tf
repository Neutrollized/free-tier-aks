###----------------------------------------
# Cluster (Control Plane) Identity
#------------------------------------------
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-cluster"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_role_assignment" "aks" {
  for_each             = toset(var.aks_cluster_user_roles)
  scope                = azurerm_resource_group.aks.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}


###-------------------------------------------------------
# UAID Kubelet Identity
# https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage
#---------------------------------------------------------
resource "azurerm_user_assigned_identity" "kubelet" {
  count               = var.enable_uaid_kubelet ? 1 : 0
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-kubelet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_role_assignment" "kubelet" {
  count                = var.enable_uaid_kubelet ? 1 : 0
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.kubelet[0].principal_id
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
