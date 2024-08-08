###----------------------------------------
# Virtual Network (VNet)
# https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
#------------------------------------------
resource "azurerm_virtual_network" "aks" {
  name                = "${var.aks_cluster_name_prefix}-${var.cluster_id}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = var.vnet_cidrs
}

resource "azurerm_subnet" "aks_system" {
  name                 = "${var.aks_cluster_name_prefix}-${var.cluster_id}-system-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = var.system_subnet_cidrs
}

resource "azurerm_subnet" "aks_user" {
  name                 = "${var.aks_cluster_name_prefix}-${var.cluster_id}-user-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = var.user_subnet_cidrs
  service_endpoints    = var.subnet_service_endpoints

  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
}


###----------------------------------------
# Network Security Groups (NSG)
# https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-network#requirement-121
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group#security_rule
# defaults rules: AllowVnetInBound, AllowAzureLoadBalancerInBound, DenyAllInBound
#------------------------------------------
resource "azurerm_network_security_group" "aks_system_subnet" {
  name                = "aksSystemSubnetsNSG"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  security_rule {
    name                       = "deny-ssh-nodepool"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "aks_user_subnets" {
  name                = "aksUserSubnetsNSG"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  security_rule {
    name                       = "deny-ssh-nodepool"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-internal"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-internal-lb"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  # NOTE 1: in Azure, LoadBalancer type in AKS is just a public IP
  #         and not a traditional LB like in GCP (for example)
  # NOTE 2: k8s creates a 500 priority rule that allows Internet to public IP
  security_rule {
    name                       = "allow-external-lb"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "system_nsg" {
  subnet_id                 = azurerm_subnet.aks_system.id
  network_security_group_id = azurerm_network_security_group.aks_system_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "user_nsg" {
  subnet_id                 = azurerm_subnet.aks_user.id
  network_security_group_id = azurerm_network_security_group.aks_user_subnets.id
}
