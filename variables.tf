###--------------------------
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
variable "address_space_cidr" {
  description = "VNet CIDR"
  type        = string
  default     = "192.168.64.0/26"
}


###--------------------------
# AKS cluster
#----------------------------
variable "aks_cluster_name_prefix" {
  description = "Prefix of the AKS cluster name.  Full name is prefix + cluster_id"
  type        = string
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

variable "azure_policy_enabled" {
  description = "Whether to enable Azure Policy add-on on the cluster"
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


###--------------------------
# AKS nodes
#----------------------------
variable "vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "node_count" {
  description = "AKS node count"
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
