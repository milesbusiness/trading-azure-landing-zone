variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "prefix"              { type = string }
variable "tenant_id"           { type = string }
variable "log_analytics_id"    { type = string }
variable "tags"                { type = map(string) default = {} }

# Key Vault — all secrets, certificates, encryption keys
resource "azurerm_key_vault" "trading" {
  name                        = "${var.prefix}-kv"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true  # DORA Art. 9 — data recoverability
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = var.tags
}

# Diagnostic settings — send Key Vault audit logs to Log Analytics (BAIT Section 8)
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kv-diagnostics"
  target_resource_id         = azurerm_key_vault.trading.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "AuditEvent" }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Azure Policy — enforce BAIT Section 5 (information security) controls
resource "azurerm_resource_group_policy_assignment" "https_only" {
  name                 = "enforce-https-only"
  resource_group_id    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  display_name         = "Secure transfer to storage accounts should be enabled"
  enforce              = true
}

resource "azurerm_resource_group_policy_assignment" "no_public_endpoints" {
  name                 = "deny-public-endpoints"
  resource_group_id    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/564feb30-bf6a-4854-b4bb-0d2d2d1e6c66"
  display_name         = "Public network access should be disabled for Cognitive Services accounts"
  enforce              = true
}

data "azurerm_client_config" "current" {}

output "key_vault_id"   { value = azurerm_key_vault.trading.id }
output "key_vault_uri"  { value = azurerm_key_vault.trading.vault_uri }
