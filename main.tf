data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "aks" {
  name     = "${var.aks_cluster_name_prefix}-${var.cluster_id}-rg"
  location = var.location
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

  kubernetes_version  = var.kubernetes_version
  run_command_enabled = var.run_command_enabled

  azure_policy_enabled      = var.azure_policy_enabled
  workload_identity_enabled = var.enable_workload_identity
  oidc_issuer_enabled       = var.enable_workload_identity || var.enable_oidc_issuer ? true : false

  api_server_access_profile {
    authorized_ip_ranges = var.aks_authorized_ip_ranges
  }

  # NOTE: object ID == principal ID
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

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

  # system node pool to host only critical system pods (i.e. CoreDNS)
  # user node pools should be created separately for workloads
  default_node_pool {
    name       = "system"
    node_count = var.system_node_count
    vm_size    = var.system_vm_size
    os_sku     = var.os_sku

    enable_node_public_ip        = var.enable_node_public_ip
    fips_enabled                 = false
    vnet_subnet_id               = azurerm_subnet.aks_system.id
    only_critical_addons_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  depends_on = [
    azurerm_role_assignment.kubelet
  ]
}


###----------------------------------------
# AKS Node Pool
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool
#------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "workloads"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.vm_size
  vnet_subnet_id        = azurerm_subnet.aks_user.id
  enable_node_public_ip = var.enable_node_public_ip

  enable_auto_scaling = true
  node_count          = var.initial_node_count
  min_count           = var.min_nodes
  max_count           = var.max_nodes

  # nodes need to have this label to use Azure Container Storage (ACS)
  node_labels = {
    "acstor.azure.com/io-engine" = "acstor"
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

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.user
  ]
}
