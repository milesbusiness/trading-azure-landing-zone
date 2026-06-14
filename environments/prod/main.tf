terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatetrading"
    container_name       = "tfstate"
    key                  = "trading-landing-zone-prod.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

variable "subscription_id" { type = string }
variable "location"        { type = string  default = "westeurope" }
variable "environment"     { type = string  default = "prod" }

locals {
  prefix = "trading-${var.environment}"
  tags = {
    environment = var.environment
    project     = "trading-platform"
    managed_by  = "terraform"
    compliance  = "mifid2-bait-dora"
  }
}

resource "azurerm_resource_group" "trading" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
}

# Log Analytics — must be created first (all modules depend on it)
resource "azurerm_log_analytics_workspace" "trading" {
  name                = "${local.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.trading.name
  sku                 = "PerGB2018"
  retention_in_days   = 90  # BAIT Section 8 — minimum 90-day log retention
  tags                = local.tags
}

module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.trading.name
  location            = var.location
  prefix              = local.prefix
  tags                = local.tags
}

module "security" {
  source              = "../../modules/security"
  resource_group_name = azurerm_resource_group.trading.name
  location            = var.location
  prefix              = local.prefix
  tenant_id           = data.azurerm_client_config.current.tenant_id
  log_analytics_id    = azurerm_log_analytics_workspace.trading.id
  tags                = local.tags
}

module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.trading.name
  location            = var.location
  cluster_name        = "${local.prefix}-aks"
  subnet_id           = module.networking.aks_subnet_id
  log_analytics_id    = azurerm_log_analytics_workspace.trading.id
  tags                = local.tags
}

module "ai_foundry" {
  source              = "../../modules/ai-foundry"
  resource_group_name = azurerm_resource_group.trading.name
  location            = var.location
  prefix              = local.prefix
  log_analytics_id    = azurerm_log_analytics_workspace.trading.id
  subnet_id           = module.networking.services_subnet_id
  tags                = local.tags
}

data "azurerm_client_config" "current" {}

output "aks_cluster_name"    { value = module.aks.cluster_name }
output "openai_endpoint"     { value = module.ai_foundry.openai_endpoint }
output "search_endpoint"     { value = module.ai_foundry.search_endpoint }
output "key_vault_uri"       { value = module.security.key_vault_uri }
