data "azuread_client_config" "current" {}

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


###-------------------------------------------------------
# IAM - Workload Identity
# https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage
# used when Workload Identity is ENABLED
# This is used by 'examples/static-azurefiles-pv'
#---------------------------------------------------------
# these should match the KSA you plan on creating/using
locals {
  ksa_name      = "nginx-wi-ksa"
  ksa_namespace = "default"
}

resource "azurerm_role_assignment" "wi_user_svcop" {
  count                = var.enable_static_azurefiles && var.enable_workload_identity ? 1 : 0
  scope                = azurerm_storage_account.mystoracct[count.index].id
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = azurerm_user_assigned_identity.wi_user[count.index].principal_id
}

resource "azurerm_role_assignment" "wi_user_smbcontrib" {
  count                = var.enable_static_azurefiles && var.enable_workload_identity ? 1 : 0
  scope                = azurerm_storage_account.mystoracct[count.index].id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_user_assigned_identity.wi_user[count.index].principal_id
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential
resource "azurerm_federated_identity_credential" "storacct_wi" {
  count               = var.enable_static_azurefiles && var.enable_workload_identity ? 1 : 0
  name                = "federated-storacct-wi-user"
  resource_group_name = azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.wi_user[count.index].id
  subject             = "system:serviceaccount:${local.ksa_namespace}:${local.ksa_name}"

  depends_on = [
    azurerm_user_assigned_identity.wi_user
  ]
}


###------------------------------------------------------------------------
# Using Azure AD (Entra ID) groups
# Creating an AAD group with the permissions to read Storage Account Key
# and assigned to the Kubelet identity
#--------------------------------------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition.html
resource "azurerm_role_definition" "storacctkey_list" {
  count       = var.enable_static_azurefiles && !var.enable_workload_identity ? 1 : 0
  name        = "Storage Account Key List"
  scope       = azurerm_storage_account.mystoracct[0].id
  description = "List Storage Account Keys ONLY"

  permissions {
    actions = ["Microsoft.Storage/storageAccounts/listkeys/action"]
  }
}

resource "azuread_group" "storacct_access" {
  count            = var.enable_static_azurefiles && !var.enable_workload_identity ? 1 : 0
  display_name     = "${azurerm_storage_account.mystoracct[0].name} Access Group"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true

  members = [
    azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id,
  ]
}

resource "azurerm_role_assignment" "storacct_op" {
  count              = var.enable_static_azurefiles && !var.enable_workload_identity ? 1 : 0
  scope              = azurerm_storage_account.mystoracct[0].id
  role_definition_id = azurerm_role_definition.storacctkey_list[0].role_definition_resource_id
  principal_type     = "Group"
  principal_id       = azuread_group.storacct_access[0].object_id
}
