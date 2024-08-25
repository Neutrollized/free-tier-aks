# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


## [0.11.0] - 2024-08-25
- New variable, `storage_profile` (type: map(bool)) used to set [Storage Profile](https://registry.terraform.io/providers/hashicorp/azurerm/3.116.0/docs/resources/kubernetes_cluster#storage_profile) settings (i.e. toggling CSI drivers)
### Removed
- Variable `disk_csi_driver_version` as setting appears to have been deprecated since provider version `3.116.0` (but not documented in provider changelog)
### Changed
- Template/formatting updates to `examples/static-azurefiles-pv`

## [0.10.0] - 2024-08-13
### Added 
- New variable, `aks_cluster_user_roles` (default: `["Contributor"]`) which contains a list of roles to assign to the AKS cluster's identity
### Changed
- Logic added to create and use user-assigned Kubelet identity only when using static Azure Files without Workload Identity
- Reorganized files

## [0.9.0] - 2024-08-09
### Added
- New variable, `run_command_enabled` (default: `false`) for toggling the [Run command](https://learn.microsoft.com/en-us/azure/aks/access-private-cluster?tabs=azure-cli#run-commands-on-your-aks-cluster) feature (leave disabled for enhanced security)
### Changed
- `iam.tf` to contain IAM resources for better organization

## [0.8.1] - 2024-08-08
### Fixed
- Workload Identity in this deployment is only used in the static Azure Files example.  When WI was enabled but static Azure Files was not, there was an error with one of the outputs.

## [0.8.0] - 2024-08-08
### Added
- Network Security Group (NSG) for AKS vnet
- `network.tf` to contain network resources for better organization

## [0.7.0] - 2024-08-07
### Added
- User node pool resource for running workloads
- New variable, `enable_oidc_issuer` (default: `false`) to toggle the [OIDC issuer URL](https://learn.microsoft.com/en-gb/azure/aks/use-oidc-issuer)
### Changed
- Default node pool in AKS cluster resource is now the designated System node pool
- VNet now has a dedicated subnet the System node pool and User node pool (for added network isolation boundary between compute tiers)

## [0.6.0] - 2024-08-01
### Added
- New variable `kubernetes_version` (default: `null`) used to specify the Kubernetes version to run. If left as `null`, the latest recommended version will be used
- Additional logic added for static Azure Files to provision user and roles when Workload Identity is enabled
### Changed
- Kubelet identity's Storage Account role assignment reduced from `Storage Account Contributor` to `Storage Account Key Operator Service Role`
- Added Workload Identity use case to `examples/static-azurefiles-pv` examples 
### Removed
- `identity` block with User Assigned identity in the Storage Account resource (it was not required, System Assigned user is sufficient) 

## [0.5.0] - 2024-07-30
### Added
- New variable `enable_static_azurefiles` (default: `false`) will toggle whether a static Azure File file share with Private Endpoint is deployed
- New variable `storacct_authorized_ip_ranges` (default: `["0.0.0.0/0"]`) is the list of IP addresses authorized to make changes, add share, etc. to your Storage Account after you've blocked public access (via Storage account network rules). Default is public, but you should lock it down to your home public IP, VPN, etc.
- `examples/static-azurefiles-pv` with example of how to use kubelet's identity to obtain [SAS token](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview) for mounting a statically provisioned Azure File storage (with [Private Endpoint](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)) for persistent volumes (PV) so that it is not stored in a kubernetes secret

## [0.4.0] - 2024-07-29
### Added
- New variable `aks_authorized_ip_ranges` (default: `["0.0.0.0/0"]`) is the list of IP addresses and CIDRs that can talk to your control plane (api-server).  Default is public, but you should change it to your home public IP (or VPN or whatever)
- New variable `enable_node_public_ip` (default: `false`)
- `kubelet_identity` user created (with `Managed Identity Operator` role)
- New variable, `enable_workload_identity` (default: `false`) to toggle [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster) on AKS (NOTE: enabling this feature will also enable the [OIDC issuer URL](https://learn.microsoft.com/en-gb/azure/aks/use-oidc-issuer))
- New variable, `subnet_service_endpoints` (default: `["Microsoft.ContainerRegistry"]`) for for defining [Service Endpoints](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview) for the VNet (even though it's set at a subnet level)
### Changed
- Subnet now has in its own resource definition (previously defined as a stanza within `azurerm_virtual_network`)

## [0.3.0] - 2024-07-10
### Added
- [`azurerm_kubernetes_cluster_extension`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_extension) resource to toggle the Azure Container Storage (ACS) extension
- New variable, `enable_acs` (default: `false`) which toggles ACS 
- New variable, `acs_azuredisk_enabled` (default: `true`) to enable Azure Disks as an ACS backend (if ACS enabled)
- New variable, `acs_azuredisk_sku` (default: `Premium_LRS`). **NOTE:** not all SKUs are supported by a Free Tier AKS cluster
- Required node label (`acstor.azure.com/io-engine: acstor`) to use ACS

## [0.2.5] - 2024-06-28
### Added
- `examples/azure-container-storage` 
### Changed
- Added `examples` folder for organization, moved `cilium` and `tetragon` folders under it

## [0.2.4] - 2024-06-22
### Added
- New variable `blob_csi_driver_enabled` (default: `false`) which toggles [Azure Blob CSI driver](https://learn.microsoft.com/en-us/azure/aks/azure-blob-csi?tabs=NFS) on the cluster 
- New variable `file_csi_driver_enabled` (default: `true`) which toggles [Azure File CSI driver](https://learn.microsoft.com/en-us/azure/aks/azure-files-csi) on the cluster 
- New variable `disk_csi_driver_enabled` (default: `true`) which toggles [Azure Disk CSI driver](https://learn.microsoft.com/en-us/azure/aks/azure-disk-csi) on the cluster 
- New variable `disk_csi_driver_version` (default: `v1`) which specifies the driver version used. `v2` (currently in preview, requires opt-in) improves scalability and reduces pod failover latency

## [0.2.3] - 2024-06-21
### Added
- New variable `azure_policy_enabled` (default: `false`) which toggles [Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes) add-on on the cluster

## [0.2.2] - 2024-05-10
### Added
- Added `tetragon` examples

## [0.2.1] - 2024-03-24
### Added
- Added `description` to output values

## [0.2.0] - 2023-11-21
### Added
- New variable `enable_ebpf_data_plane` (default: `false`) which configures AKS with [Azure CNI powered by Cilium](https://learn.microsoft.com/en-us/azure/aks/azure-cni-powered-by-cilium)
- New variable `network_policy` (default: `null`) which selects the network policy to be used with Azure CNI. Supported options are: `calico`, `azure`, `cilium` or `null`
- New variable `os_sku` (default: `Ubuntu`)
- Added `terraform.tfvars.sample`
- [Terrafom Tests](./tests)

## [0.1.0] - 2023-11-16
### Added
- Initial commit
