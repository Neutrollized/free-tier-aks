###----------------------------------------
# Statically Provisioned Azure Files
# - resource provisioned only when enable_static_azurefiles = true
# - see examples/static-azurefiles-pv for more details
#------------------------------------------
locals {
  storacct_rg      = "azurefiles-storage-rg"
  azurefiles_share = "myfileshare"
}

# added 4 random chars to Storage Account name as suffix
resource "random_id" "name_suffix" {
  count       = var.enable_static_azurefiles ? 1 : 0
  byte_length = 2
}

resource "azurerm_resource_group" "storacctrg" {
  count    = var.enable_static_azurefiles ? 1 : 0
  name     = local.storacct_rg
  location = var.location
}

resource "azurerm_storage_account" "mystoracct" {
  count               = var.enable_static_azurefiles ? 1 : 0
  name                = "azurefilessa${random_id.name_suffix[count.index].hex}"
  resource_group_name = azurerm_resource_group.storacctrg[count.index].name
  location            = azurerm_resource_group.storacctrg[count.index].location

  account_kind             = "FileStorage"
  account_tier             = "Premium"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.storacct_authorized_ip_ranges
  }
}


###-------------------------------------------------------
# Private Endpoint
# https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#storage
#---------------------------------------------------------
resource "azurerm_private_endpoint" "sa_pvtep" {
  count               = var.enable_static_azurefiles ? 1 : 0
  name                = "${azurerm_storage_account.mystoracct[count.index].name}-pvtendpoint"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  subnet_id           = azurerm_subnet.aks.id

  private_service_connection {
    name                           = "azurefiles-pvtsvcconnection"
    private_connection_resource_id = azurerm_storage_account.mystoracct[count.index].id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${azurerm_storage_account.mystoracct[count.index].name}-dnszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.pvtzone[count.index].id]
  }
}

resource "azurerm_private_dns_zone" "pvtzone" {
  count               = var.enable_static_azurefiles ? 1 : 0
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pvtzone_link" {
  count                 = var.enable_static_azurefiles ? 1 : 0
  name                  = "vnet-storacct-link"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.pvtzone[count.index].name
  virtual_network_id    = azurerm_virtual_network.aks.id
}


###-------------------------------------------------------
# Azure Files file share
#---------------------------------------------------------
resource "azurerm_storage_share" "myfileshare" {
  count                = var.enable_static_azurefiles ? 1 : 0
  name                 = local.azurefiles_share
  storage_account_name = azurerm_storage_account.mystoracct[count.index].name
  access_tier          = "Premium"
  quota                = 101 # (max) size of share in GiB -- needs to be > 100 for Premium access tier

  depends_on = [
    azurerm_private_endpoint.sa_pvtep,
    azurerm_private_dns_zone_virtual_network_link.pvtzone_link
  ]
}


###-------------------------------------------------------
# IAM - Kubelet Identity
# https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage
# used when Workload Identity is DISABLED
#---------------------------------------------------------
resource "azurerm_role_assignment" "kubelet_svcop" {
  count                = var.enable_static_azurefiles && !var.enable_workload_identity ? 1 : 0
  scope                = azurerm_storage_account.mystoracct[count.index].id
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
}


###-------------------------------------------------------
# IAM - Workload Identity
# https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage
# used when Workload Identity is ENABLED
#---------------------------------------------------------
# these should match the KSA you plan on creating/using
locals {
  ksa_name      = "nginx-wi-ksa"
  ksa_namespace = "default"
}

resource "azurerm_user_assigned_identity" "wi_user" {
  count               = var.enable_static_azurefiles && var.enable_workload_identity ? 1 : 0
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-wi-user"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
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
