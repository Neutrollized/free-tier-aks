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
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}


###----------------------------------------
# AKS
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
#------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku_tier            = var.sku_tier
  dns_prefix          = "${var.aks_cluster_name_prefix}-${var.cluster_id}"

  azure_policy_enabled = var.azure_policy_enabled

  network_profile {
    ebpf_data_plane = var.enable_ebpf_data_plane ? "cilium" : null

    network_plugin      = var.enable_ebpf_data_plane ? "azure" : var.network_plugin
    network_plugin_mode = var.network_plugin == "azure" || var.enable_ebpf_data_plane ? "overlay" : null
    network_policy      = var.enable_ebpf_data_plane ? "cilium" : var.network_policy

    pod_cidrs      = var.pods_ipv4_cidr_block
    service_cidrs  = var.services_ipv4_cidr_block
    dns_service_ip = var.dns_service_ip
  }

  storage_profile {
    blob_driver_enabled = var.blob_csi_driver_enabled
    file_driver_enabled = var.file_csi_driver_enabled

    disk_driver_enabled = var.disk_csi_driver_enabled
    disk_driver_version = var.disk_csi_driver_version
  }

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    os_sku     = var.os_sku

    enable_node_public_ip = true
    fips_enabled          = false
    vnet_subnet_id        = azurerm_virtual_network.aks.subnet.*.id[0]

    # nodes need to have this label to use Azure Container Storage (ACS)
    node_labels = {
      "acstor.azure.com/io-engine" = "acstor"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
}


###--------------------------------------------------
# AKS Extensions
# https://learn.microsoft.com/en-us/azure/aks/cluster-extensions?tabs=azure-cli#currently-available-extensions
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_extension
#----------------------------------------------------
resource "azurerm_kubernetes_cluster_extension" "acs" {
  count          = var.enable_acs ? 1 : 0
  name           = "azurecontainerstorage"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.azurecontainerstorage"

  configuration_settings = {
    "global.cli.activeControl"                   = true
    "global.cli.storagePool.install.create"      = false
    "global.cli.storagePool.disable.validation"  = false
    "global.cli.storagePool.disable.active"      = false
    "global.cli.storagePool.azureDisk.enabled"   = var.acs_azuredisk_enabled
    "global.cli.storagePool.azureDisk.sku"       = var.acs_azuredisk_sku
    "global.cli.resources.num_hugepages"         = "512"
    "global.cli.resources.ioEngine.cpu"          = "1"
    "global.cli.resources.ioEngine.memory"       = "1Gi"
    "global.cli.resources.ioEngine.hugepages2Mi" = "1Gi"
  }
}
