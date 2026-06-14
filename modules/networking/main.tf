variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "prefix"              { type = string }
variable "hub_cidr"            { type = string  default = "10.0.0.0/16" }
variable "spoke_cidr"          { type = string  default = "10.1.0.0/16" }
variable "tags"                { type = map(string) default = {} }

# Hub VNet — firewall, bastion, VPN
resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-hub-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_cidr]
  tags                = var.tags
}

# Spoke VNet — AKS, services, private endpoints
resource "azurerm_virtual_network" "spoke" {
  name                = "${var.prefix}-spoke-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.spoke_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_subnet" "services" {
  name                 = "snet-services"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.1.4.0/24"]
  private_endpoint_network_policies = "Disabled"
}

# VNet peering hub <-> spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

output "aks_subnet_id"      { value = azurerm_subnet.aks.id }
output "services_subnet_id" { value = azurerm_subnet.services.id }
output "hub_vnet_id"        { value = azurerm_virtual_network.hub.id }
output "spoke_vnet_id"      { value = azurerm_virtual_network.spoke.id }
