# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
- New variables `enable_ebpf_data_plane` (default: `false`) which configures AKS with [Azure CNI powered by Cilium](https://learn.microsoft.com/en-us/azure/aks/azure-cni-powered-by-cilium)
- New variable `network_policy` (default: `null`) which selects the network policy to be used with Azure CNI. Supported options are: `calico`, `azure`, `cilium` or `null`
- New variable `os_sku` (default: `Ubuntu`)
- Added `terraform.tfvars.sample`
- [Terrafom Tests](./tests)

## [0.1.0] - 2023-11-16
### Added
- Initial commit
