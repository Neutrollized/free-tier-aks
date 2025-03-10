##--------------------------
# Provider variables
#----------------------------
variable "location" {
  description = "Location"
  type        = string
  default     = "canadacentral"
}


###--------------------------
# Cilium
#----------------------------
variable "cilium_version" {
  description = "Version of Cilium to install.  Get list of available versions with 'cilium install --list-versions'"
  type        = string
}

variable "cluster_id" {
  description = "Cluster ID for Cilium ClusterMesh"
  type        = number
}


###--------------------------
# VNet
#----------------------------
variable "vnet_cidrs" {
  description = "VNet CIDR"
  type        = list(string)
  default     = ["192.168.0.0/24"]
}

variable "system_subnet_cidrs" {
  description = "Subnet CIDR for System Node Pool"
  type        = list(string)
  default     = ["192.168.0.0/25"]
}

variable "user_subnet_cidrs" {
  description = "Subnet CIDR for User Node Pool"
  type        = list(string)
  default     = ["192.168.0.128/25"]
}

variable "subnet_service_endpoints" {
  description = "List of Service Endpoints"
  type        = list(string)
  default     = ["Microsoft.ContainerRegistry"]
}


###--------------------------
# AKS identities & roles
#----------------------------
variable "aks_cluster_user_roles" {
  description = "List of roles to assign to the AKS cluster user"
  type        = list(string)
  default     = ["Contributor"]
}

variable "enable_uaid_kubelet" {
  description = "Whether to use a user-assigned ID for Kubelet"
  type        = bool
  default     = false
}


###--------------------------
# AKS cluster
#----------------------------
variable "aks_authorized_ip_ranges" {
  description = "Authorized IP ranges that is allowed access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "aks_cluster_name_prefix" {
  description = "Prefix of the AKS cluster name.  Full name is prefix + cluster_id"
  type        = string
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to run. If left as null, the latest recommended version will be used"
  type        = string
  default     = null
}

variable "run_command_enabled" {
  description = "Toggles whether to allow 'az aks command invoke' to interact directly with cluster"
  type        = bool
  default     = false
}

variable "sku_tier" {
  description = "AKS tier"
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "Accepted values are 'Free' or 'Standard'"
  }
}

variable "enable_ebpf_data_plane" {
  description = "Specifies eBPF data plane to use (whether to use Cilium or not)"
  type        = bool
  default     = false
}

variable "network_plugin" {
  description = "AKS network plugin type.  If you want to BYOCNI (i.e. OSS Cilium), select 'none'"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["azure", "kubenet", "none"], var.network_plugin)
    error_message = "Accepted values are 'azure', 'kubenet' or 'none'"
  }
}

variable "aks_auto_upgrade_channel" {
  description = "Upgrade channel for AKS"
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "patch", "rapid", "node-image", "stable"], var.aks_auto_upgrade_channel)
    error_message = "Accepted values are '', 'patch', 'rapid', 'node-image' or 'stable'"
  }
}

variable "azure_policy_enabled" {
  description = "Whether to enable Azure Policy add-on on the cluster"
  type        = bool
  default     = false
}

variable "enable_workload_identity" {
  description = "Whether to enable Azure AD Workload Identity on the cluster.  Enabling this will also enable the OIDC issuer URL"
  type        = bool
  default     = false
}

variable "enable_oidc_issuer" {
  description = "Whether to enable the OIDC issuer URL"
  type        = bool
  default     = false
}

variable "network_policy" {
  description = "Network policy to be used Azure CNI. Accepted values are 'calico', 'azure', 'cilium' or null"
  type        = string
  default     = null
  nullable    = true
}

variable "pods_ipv4_cidr_block" {
  description = "Pod address CIDR"
  type        = list(string)
  default     = ["10.100.0.0/18"]
}

variable "services_ipv4_cidr_block" {
  description = "Service address CIDR"
  type        = list(string)
  default     = ["10.101.0.0/20"]
}

variable "dns_service_ip" {
  description = "Kube DNS service address"
  type        = string
  default     = "10.101.0.10"
}

variable "storage_profile" {
  description = "Toggles for storage profile (CSI) settings"
  type        = map(bool)
  default = {
    blob_csi_driver_enabled     = false
    disk_csi_driver_enabled     = true
    file_csi_driver_enabled     = false
    snapshot_controller_enabled = true
  }
}

variable "system_vm_size" {
  description = "AKS system node pool VM size"
  type        = string
  default     = "Standard_D2_v3"
}

variable "system_node_count" {
  description = "AKS system node pool count"
  type        = number
  default     = 1
}

variable "os_sku" {
  description = "Node OS SKU"
  type        = string
  default     = "Ubuntu"

  validation {
    condition     = contains(["AzureLinux", "CBLMariner", "Mariner", "Ubuntu", "Windows2019", "Windows2022"], var.os_sku)
    error_message = "Accepted values are 'AzureLinux', 'CBLMariner' 'Mariner', 'Ubuntu', 'Windows2019' or 'Windows2022'"
  }
}

variable "enable_node_public_ip" {
  description = "Whether nodes in the node pool should have a public IP"
  type        = bool
  default     = false
}


###--------------------------
# AKS nodes
#----------------------------
variable "vm_size" {
  description = "AKS user node pool VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "initial_node_count" {
  description = "AKS user node pool count"
  type        = number
  default     = 1
}

variable "min_nodes" {
  description = "Min number of nodes in node pool"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Max number of nodes in node pool"
  type        = number
  default     = 3
}


###--------------------------
# AKS extension - ACS
#----------------------------
variable "enable_acs" {
  description = "Whether to enable Azure Container Storage"
  type        = bool
  default     = false
}

variable "acs_config" {
  description = "Azure Container Storage configuration settings"
  type = object({
    activecontrol                           = optional(bool, true)
    storagepool_install_create              = optional(bool, false)
    storagepool_install_name                = optional(string, "azuredisk")
    storagepool_install_size                = optional(string, "512Gi")
    storagepool_disable_validation          = optional(bool, false)
    storagepool_disable_active              = optional(bool, false)
    storagepool_azuredisk_enabled           = optional(bool, true)
    storagepool_elasticsan_enabled          = optional(bool, false)
    storagepool_ephemeraldisk_nvme_enabled  = optional(bool, false)
    storagepool_ephemeraldisk_nvme_perftier = optional(string, "Standard")
    storagepool_ephemeraldisk_temp_enabled  = optional(bool, false)
    storagepool_azuredisk_sku               = optional(string, "Premium_LRS")
    resources_num_hugepages                 = optional(number, 512)
    resources_ioengine_cpu                  = optional(number, 1)
    resources_ioengine_memory               = optional(string, "1Gi")
    resources_ioengine_hugepages2mi         = optional(string, "1Gi")
  })
  default = {}

  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS", "UltraSSD_LRS", "Premium_ZRS", "PremiumV2_LRS", "StandardSSD_ZRS"], var.acs_config.storagepool_azuredisk_sku)
    error_message = "Accepted values are 'Premium_LRS', 'Standard_LRS', 'StandardSSD_LRS', 'UltraSSD_LRS', 'Premium_ZRS', 'PremiumV2_LRS', or 'StandardSSD_ZRS'"
  }
}
