# Call the setup module to create a random cluster name
run "setup_tests" {
  module {
    source = "./tests/setup"
  }
}


# Apply run block to create GKE cluster
run "create_free_tier_aks" {
  variables {
    aks_cluster_name_prefix = run.setup_tests.cluster_name_prefix
    cluster_id              = run.setup_tests.cluster_id
    enable_ebpf_data_plane  = true
  }

  # Check that the cluster name is correct
  assert {
    condition     = azurerm_kubernetes_cluster.aks.name == "${run.setup_tests.cluster_name_prefix}-${run.setup_tests.cluster_id}"
    error_message = "Invalid AKS cluster name"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.location == "canadacentral"
    error_message = "Invalid AKS cluster location"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.sku_tier == "Free"
    error_message = "Invalid SKU tier"
  }

  # Check that Cilium CNI is enabled correctly
  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_data_plane == "cilium"
    error_message = "Invalid dataplane"
  }
}
