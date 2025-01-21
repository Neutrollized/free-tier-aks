###--------------------------------------------------
# AKS Extensions
# https://learn.microsoft.com/en-us/azure/aks/cluster-extensions?tabs=azure-cli#currently-available-extensions
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_extension
#----------------------------------------------------
resource "azurerm_kubernetes_cluster_extension" "acs" {
  count          = var.enable_acs ? 1 : 0
  name           = "azurecontainerstorage"
  version        = "1.2.0"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.azurecontainerstorage"

  configuration_settings = {
    "global.cli.activeControl"                           = lookup(var.acs_config, "activecontrol")
    "global.cli.storagePool.install.create"              = lookup(var.acs_config, "storagepool_install_create")
    "global.cli.storagePool.install.name"                = lookup(var.acs_config, "storagepool_install_name")
    "global.cli.storagePool.disable.validation"          = lookup(var.acs_config, "storagepool_disable_validation")
    "global.cli.storagePool.disable.active"              = lookup(var.acs_config, "storagepool_disable_active")
    "global.cli.storagePool.azureDisk.enabled"           = lookup(var.acs_config, "storagepool_azuredisk_enabled")
    "global.cli.storagePool.azureDisk.sku"               = lookup(var.acs_config, "storagepool_azuredisk_sku")
    "global.cli.storagePool.elasticSan.enabled"          = lookup(var.acs_config, "storagepool_elasticsan_enabled")
    "global.cli.storagePool.ephemeralDisk.nvme.enabled"  = lookup(var.acs_config, "storagepool_ephemeraldisk_nvme_enabled")
    "global.cli.storagePool.ephemeralDisk.nvme.perfTier" = lookup(var.acs_config, "storagepool_ephemeraldisk_nvme_perftier")
    "global.cli.storagePool.ephemeralDisk.temp.enabled"  = lookup(var.acs_config, "storagepool_ephemeraldisk_temp_enabled")
    "global.cli.resources.num_hugepages"                 = lookup(var.acs_config, "resources_num_hugepages")
    "global.cli.resources.ioEngine.cpu"                  = lookup(var.acs_config, "resources_ioengine_cpu")
    "global.cli.resources.ioEngine.memory"               = lookup(var.acs_config, "resources_ioengine_memory")
    "global.cli.resources.ioEngine.hugepages2Mi"         = lookup(var.acs_config, "resources_ioengine_hugepages2mi")
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.user
  ]
}
