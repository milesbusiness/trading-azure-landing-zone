terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "cluster_name"        { type = string }
variable "kubernetes_version"  { type = string  default = "1.30" }
variable "system_node_count"   { type = number  default = 3 }
variable "user_node_min"       { type = number  default = 3 }
variable "user_node_max"       { type = number  default = 20 }
variable "system_vm_size"      { type = string  default = "Standard_D4s_v5" }
variable "user_vm_size"        { type = string  default = "Standard_D8s_v5" }
variable "subnet_id"           { type = string }
variable "log_analytics_id"    { type = string }
variable "tags"                { type = map(string) default = {} }

resource "azurerm_kubernetes_cluster" "trading" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # System node pool — runs AKS system components
  default_node_pool {
    name                        = "system"
    node_count                  = var.system_node_count
    vm_size                     = var.system_vm_size
    vnet_subnet_id              = var.subnet_id
    only_critical_addons_enabled = true
    zones                       = ["1", "2", "3"]
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_id
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
    secret_rotation_interval = "2m"
  }

  auto_scaler_profile {
    balance_similar_node_groups  = true
    skip_nodes_with_system_pods  = true
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+01:00"
    duration    = 4
  }

  tags = var.tags
}

# User node pool — runs trading workloads
resource "azurerm_kubernetes_cluster_node_pool" "trading" {
  name                  = "trading"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.trading.id
  vm_size               = var.user_vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = ["1", "2", "3"]

  enable_auto_scaling = true
  min_count           = var.user_node_min
  max_count           = var.user_node_max

  node_labels = {
    "workload-type" = "trading"
    "tier"          = "user"
  }

  node_taints = [
    "workload=trading:NoSchedule"
  ]

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}

output "cluster_id"          { value = azurerm_kubernetes_cluster.trading.id }
output "cluster_name"        { value = azurerm_kubernetes_cluster.trading.name }
output "kube_config"         { value = azurerm_kubernetes_cluster.trading.kube_config_raw  sensitive = true }
output "kubelet_identity_id" { value = azurerm_kubernetes_cluster.trading.kubelet_identity[0].object_id }
