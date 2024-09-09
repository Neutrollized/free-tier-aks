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

  # account_kind             = "FileStorage" # default: StorageV2
  # account_tier             = "Premium"
  account_tier             = "Standard"
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
  subnet_id           = azurerm_subnet.aks_user.id

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
  # access_tier          = "Premium"
  access_tier = "TransactionOptimized"
  quota       = 101 # (max) size of share in GiB -- needs to be > 100 if using Premium access tier

  depends_on = [
    azurerm_private_endpoint.sa_pvtep,
    azurerm_private_dns_zone_virtual_network_link.pvtzone_link
  ]
}
