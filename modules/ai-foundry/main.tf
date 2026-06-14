variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "prefix"              { type = string }
variable "log_analytics_id"    { type = string }
variable "subnet_id"           { type = string }
variable "tags"                { type = map(string) default = {} }

# Azure OpenAI
resource "azurerm_cognitive_account" "openai" {
  name                  = "${var.prefix}-openai"
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "${var.prefix}-openai"
  public_network_access_enabled = false  # Private endpoint only (BAIT Section 11)

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  scale {
    type     = "Standard"
    capacity = 30
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-3-large"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  depends_on           = [azurerm_cognitive_deployment.gpt4o]

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  scale {
    type     = "Standard"
    capacity = 120
  }
}

# Azure AI Search
resource "azurerm_search_service" "main" {
  name                = "${var.prefix}-search"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "standard"
  replica_count       = 2
  partition_count     = 1
  semantic_search_sku = "standard"
  public_network_access_enabled = false

  tags = var.tags
}

# Azure Event Hubs (Premium — dedicated, no noisy neighbours)
resource "azurerm_eventhub_namespace" "trading" {
  name                = "${var.prefix}-eh"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Premium"
  capacity            = 4
  zone_redundant      = true

  tags = var.tags
}

resource "azurerm_eventhub" "trade_events" {
  name                = "trade-events"
  namespace_name      = azurerm_eventhub_namespace.trading.name
  resource_group_name = var.resource_group_name
  partition_count     = 32
  message_retention   = 7
}

output "openai_endpoint"     { value = azurerm_cognitive_account.openai.endpoint }
output "openai_id"           { value = azurerm_cognitive_account.openai.id }
output "search_endpoint"     { value = "https://${azurerm_search_service.main.name}.search.windows.net" }
output "eventhub_namespace"  { value = azurerm_eventhub_namespace.trading.name }
