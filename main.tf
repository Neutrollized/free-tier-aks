data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "aks" {
  name     = "${var.aks_cluster_name_prefix}-${var.cluster_id}-rg"
  location = var.location
}


###----------------------------------------
# Network
#------------------------------------------
resource "azurerm_virtual_network" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = [var.address_space_cidr]


  subnet {
    name           = "aks-node-subnet"
    address_prefix = var.address_space_cidr
  }
}


###----------------------------------------
# IAM
#------------------------------------------
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-user"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
}

resource "azurerm_role_assignment" "aks" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}


###----------------------------------------
# AKS
#------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku_tier            = var.sku_tier
  dns_prefix          = "${var.aks_cluster_name_prefix}-${var.cluster_id}"

  network_profile {
    network_plugin = var.network_plugin

    pod_cidrs      = var.pods_ipv4_cidr_block
    service_cidrs  = var.services_ipv4_cidr_block
    dns_service_ip = var.dns_service_ip
  }

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size

    enable_node_public_ip = true
    fips_enabled          = false
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
}
