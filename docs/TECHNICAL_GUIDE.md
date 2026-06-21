# Technical Guide — Trading Azure Landing Zone

> This guide explains every technology used, how to learn it, how to install the project, what every file does, and how to deploy and verify the output.

---

## Table of Contents

1. [Technologies Used](#1-technologies-used)
2. [Where to Learn Each Technology](#2-where-to-learn-each-technology)
3. [Installation — Step by Step](#3-installation--step-by-step)
4. [Project File Structure](#4-project-file-structure)
5. [Code Walkthrough — Every File Explained](#5-code-walkthrough--every-file-explained)
6. [How to Deploy and View Output](#6-how-to-deploy-and-view-output)

---

## 1. Technologies Used

| Technology | Version | What it is | Why it is used here |
|-----------|---------|-----------|-------------------|
| **Terraform** | 1.9 | Infrastructure as Code tool by HashiCorp | Declares ALL Azure resources as code; provisions them repeatably |
| **Azure Resource Manager (ARM)** | — | Microsoft's Azure deployment API | Terraform calls ARM under the hood to create every resource |
| **azurerm Terraform provider** | ~4.0 | Terraform plugin for Azure | Provides all `azurerm_*` resource types (VNets, AKS, Key Vault, etc.) |
| **Azure Virtual Network** | — | Azure networking service | Hub-spoke network isolation; contains all resources |
| **Azure Firewall** | — | Azure managed firewall | Inspects and logs all outbound internet traffic from the spoke |
| **Azure Bastion** | — | Secure admin jump service | SSH/RDP to VMs without exposing public ports |
| **Azure Kubernetes Service (AKS)** | 1.30 | Managed Kubernetes | Runs trading workloads; configured with two node pools |
| **Azure Key Vault** | — | Secrets management service | Stores API keys, connection strings, certificates |
| **Azure Policy** | — | Azure governance service | Enforces compliance rules automatically (deny public endpoints, require HTTPS) |
| **Azure Monitor / Log Analytics** | — | Azure observability platform | Collects all diagnostic logs; 90-day retention for BAIT compliance |
| **Microsoft Defender for Containers** | — | Azure security product | Runtime threat detection for AKS pods |
| **Azure OpenAI** | — | Azure AI service | GPT-4o and text-embedding-3-large with private endpoint |
| **Azure AI Search** | Standard S1 | Azure vector search service | Hybrid semantic search with private endpoint |
| **Azure Event Hubs** | Premium 4PU | Azure streaming service | Transaction feed for MiFID II transaction reporting |
| **Terraform backend (Azure Blob)** | — | Remote state storage | Stores the Terraform state file remotely so multiple team members can collaborate |

**Official Links:**
- Terraform: https://www.terraform.io/docs
- Terraform Azure Provider: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- AKS Terraform resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
- Key Vault Terraform resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
- Azure Policy built-in definitions: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies
- BAIT (BaFin): https://www.bafin.de/SharedDocs/Downloads/EN/Rundschreiben/dl_rs_1710_bait_en.html
- DORA regulation text: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32022R2554

---

## 2. Where to Learn Each Technology

### Terraform

**Official:**
- https://developer.hashicorp.com/terraform/tutorials — Free interactive tutorials (most important: start here)
- https://developer.hashicorp.com/terraform/tutorials/azure-get-started — Azure-specific track
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs — azurerm provider reference

**YouTube:**
- "Complete Terraform Tutorial" by TechWorld with Nana — https://www.youtube.com/@TechWorldwithNana
- "Terraform on Azure" by Microsoft Azure — https://www.youtube.com/@MicrosoftAzure (search "Terraform")

**Free hands-on labs:**
- https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build — Deploy your first Azure resources

**What to learn in order:**
1. `terraform init`, `terraform plan`, `terraform apply`, `terraform destroy` — the 4 core commands
2. `resource` blocks — how to declare Azure resources
3. `variable` and `output` blocks — parameterisation
4. `module` blocks — how to reuse groups of resources
5. `backend` configuration — remote state

### Azure Networking (Hub-Spoke)

**Official:**
- https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke — Hub-spoke reference architecture
- https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview — VNet overview
- https://learn.microsoft.com/azure/firewall/overview — Azure Firewall

**YouTube:**
- "Azure Networking fundamentals" by John Savill — https://www.youtube.com/@NTFAQGuy (best Azure architecture channel)

### Azure Policy

**Official:**
- https://learn.microsoft.com/azure/governance/policy/overview — What Azure Policy is
- https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies — List of all built-in policy definitions (you can find the `policyDefinitionId` values here)

### Key Vault

**Official:**
- https://learn.microsoft.com/azure/key-vault/general/overview
- https://learn.microsoft.com/azure/key-vault/general/rbac-guide — RBAC for Key Vault

---

## 3. Installation — Step by Step

### Step 1 — Install Required Tools

```powershell
# Terraform
winget install HashiCorp.Terraform
# Verify:
terraform version
# Should show: Terraform v1.9.x

# Azure CLI
winget install Microsoft.AzureCLI
# Verify:
az version

# Login to Azure
az login
# Your browser opens, log in with your Azure account
az account show   # Confirms which subscription is active
```

Terraform download page: https://developer.hashicorp.com/terraform/downloads
Azure CLI download: https://learn.microsoft.com/cli/azure/install-azure-cli-windows

### Step 2 — Clone the Repository

```powershell
git clone https://github.com/milesbusiness/trading-azure-landing-zone
cd trading-azure-landing-zone
```

### Step 3 — Create Remote State Storage

Terraform needs somewhere to store its state file (the record of what it has created). We put it in Azure Blob Storage:

```powershell
# Create a resource group for state (separate from the actual infrastructure)
az group create --name rg-terraform-state --location westeurope

# Create a storage account
az storage account create `
  --name tfstatetrading `
  --resource-group rg-terraform-state `
  --sku Standard_LRS `
  --allow-blob-public-access false

# Create the container
az storage container create `
  --name tfstate `
  --account-name tfstatetrading
```

This only needs to be done once. The state file will persist even after you destroy and recreate the infrastructure.

### Step 4 — Configure Variables

```powershell
cd environments/prod
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
subscription_id = "your-azure-subscription-id"
location        = "westeurope"
environment     = "prod"
```

Get your subscription ID:
```powershell
az account show --query id -o tsv
```

### Step 5 — Deploy

```powershell
# Step 5a: Initialise — downloads the azurerm provider, connects to remote state
terraform init

# Step 5b: Plan — shows EXACTLY what will be created (no changes made yet)
terraform plan -var-file=terraform.tfvars -out=tfplan

# Read the plan output carefully before applying!
# Lines with "+" = resources that will be CREATED
# Lines with "-" = resources that will be DESTROYED
# Lines with "~" = resources that will be MODIFIED

# Step 5c: Apply — creates the actual Azure resources (~15 minutes)
terraform apply tfplan
```

---

## 4. Project File Structure

```
trading-azure-landing-zone/
├── environments/
│   └── prod/
│       ├── main.tf              ← Root module: declares all child modules, creates Log Analytics
│       └── terraform.tfvars     ← YOUR variable values (gitignored)
│
└── modules/
    ├── networking/
    │   └── main.tf              ← Hub VNet, spoke VNet, subnets, VNet peering
    ├── aks/
    │   └── main.tf              ← AKS cluster: system node pool + trading node pool
    ├── security/
    │   └── main.tf              ← Key Vault, Azure Policy assignments, diagnostic settings
    ├── ai-foundry/
    │   └── main.tf              ← Azure OpenAI, AI Search, Event Hubs (all private endpoint)
    └── monitoring/
        └── main.tf              ← Log Analytics workspace, diagnostic settings, alerts
```

**Why modules?** Each module is an independent group of related resources. The `environments/prod/main.tf` composes them together. This means you can test each module independently, reuse them across environments, and change one module without touching others.

---

## 5. Code Walkthrough — Every File Explained

### `environments/prod/main.tf` — The Root Configuration

```hcl
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"    # Allows 4.x but not 5.x
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatetrading"
    container_name       = "tfstate"
    key                  = "trading-landing-zone-prod.tfstate"   # Filename in the container
  }
}
```
The `backend "azurerm"` block tells Terraform to store its state file in Azure Blob Storage instead of locally. Without this, two people running `terraform apply` simultaneously could corrupt the state.

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false      # Never hard-delete Key Vault on terraform destroy
      recover_soft_deleted_key_vaults = true    # Recover if it already exists in soft-delete
    }
    resource_group {
      prevent_deletion_if_contains_resources = true   # Safety: don't delete a resource group that has resources
    }
  }
}
```
Provider-level safety settings. `purge_soft_delete_on_destroy = false` is critical — Key Vault has a 90-day soft-delete period. Without this setting, `terraform destroy` would leave a ghost Key Vault in the soft-delete state and prevent re-creation with the same name.

```hcl
locals {
  prefix = "trading-${var.environment}"    # e.g., "trading-prod"
  tags = {
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "mifid2-bait-dora"       # Compliance tag on every resource
  }
}
```
`locals` are computed values. The `tags` map is applied to every resource in every module — Azure Portal will show these tags on every resource, making it easy to filter by environment or compliance status.

```hcl
resource "azurerm_log_analytics_workspace" "trading" {
  name                = "${local.prefix}-law"
  retention_in_days   = 90    # BAIT Section 8 — minimum 90-day log retention
  tags                = local.tags
}
```
Log Analytics is created in the root module (not a sub-module) because every other module needs its `id` — it must be created first. The comment `# BAIT Section 8` is important for audit purposes — it links the configuration choice to the regulatory requirement.

```hcl
module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.trading.name
  location            = var.location
  prefix              = local.prefix
  tags                = local.tags
}
```
Module instantiation. `source` points to the module directory. All variables defined in `modules/networking/main.tf` must be passed here. The module output values are accessed as `module.networking.aks_subnet_id`.

```hcl
output "aks_cluster_name"    { value = module.aks.cluster_name }
output "openai_endpoint"     { value = module.ai_foundry.openai_endpoint }
output "key_vault_uri"       { value = module.security.key_vault_uri }
```
Outputs are printed after `terraform apply` completes — these are the values your application teams need to configure their applications.

---

### `modules/networking/main.tf` — Hub-Spoke Network

```hcl
resource "azurerm_virtual_network" "hub" {
  name          = "${var.prefix}-hub-vnet"
  address_space = [var.hub_cidr]   # Default: 10.0.0.0/16
}

resource "azurerm_virtual_network" "spoke" {
  name          = "${var.prefix}-spoke-vnet"
  address_space = [var.spoke_cidr]  # Default: 10.1.0.0/16
}
```
Two separate Virtual Networks. The hub contains shared services (Firewall, Bastion). The spoke contains the application resources (AKS, private endpoints). The separation means AKS pods cannot directly reach the Firewall control plane.

```hcl
resource "azurerm_subnet" "aks" {
  name             = "snet-aks"
  address_prefixes = ["10.1.0.0/22"]    # 1,022 IP addresses for AKS pods
}

resource "azurerm_subnet" "services" {
  name             = "snet-services"
  address_prefixes = ["10.1.4.0/24"]    # 254 IP addresses for private endpoints
  private_endpoint_network_policies = "Disabled"   # Required for private endpoints to work
}
```
Two subnets in the spoke:
- AKS subnet `/22` = 1,022 addresses — enough for 20+ nodes with many pods each
- Services subnet `/24` = 254 addresses — one private endpoint uses one IP

```hcl
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
```
VNet peering must be created in both directions — hub→spoke AND spoke→hub. Both `allow_forwarded_traffic = true` means traffic can be forwarded through the Azure Firewall in the hub.

---

### `modules/aks/main.tf` — Kubernetes Cluster

```hcl
default_node_pool {
  name                         = "system"
  node_count                   = var.system_node_count     # Default: 3
  vm_size                      = var.system_vm_size        # Default: Standard_D4s_v5
  only_critical_addons_enabled = true                      # Only DNS, metrics, etc. on this pool
  zones                        = ["1", "2", "3"]           # Spread across 3 AZs
}
```
The `only_critical_addons_enabled = true` is the critical setting — it tells Kubernetes to taint this node pool so only system-critical pods (CoreDNS, metrics-server, etc.) are scheduled here. Trading application pods will not run here — they go to the `trading` node pool.

`zones = ["1", "2", "3"]` — spreads nodes across 3 Azure Availability Zones (physically separate data centres). If zone 1 goes down, zones 2 and 3 continue serving traffic.

```hcl
microsoft_defender {
  log_analytics_workspace_id = var.log_analytics_id
}

key_vault_secrets_provider {
  secret_rotation_enabled  = true
  secret_rotation_interval = "2m"    # Rotate secrets every 2 minutes
}
```
`microsoft_defender` — enables Defender for Containers, which detects runtime threats inside pods (unusual syscalls, privilege escalation attempts, unexpected network connections).

`key_vault_secrets_provider` — the AKS Secret Store CSI Driver. Secrets from Key Vault are automatically mounted into pods as files, and refreshed every 2 minutes. This means rotating an API key in Key Vault automatically propagates to all running pods within 2 minutes — no pod restart required.

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "trading" {
  name    = "trading"
  vm_size = var.user_vm_size        # Default: Standard_D8s_v5 (8 vCPU, 32GB RAM)
  zones   = ["1", "2", "3"]
  enable_auto_scaling = true
  min_count           = var.user_node_min    # Default: 3
  max_count           = var.user_node_max    # Default: 20

  node_taints = [
    "workload=trading:NoSchedule"    # Only pods with matching tolerations can land here
  ]
}
```
The `node_taints` with `NoSchedule` is a key Kubernetes concept. Without a matching `toleration` in its manifest, a pod will not be scheduled on these nodes. Only pods with `tolerations: [{key: "workload", value: "trading"}]` can land here — ensuring trading workloads run exclusively on the high-performance `Standard_D8s_v5` nodes.

---

### `modules/security/main.tf` — Key Vault and Azure Policy

```hcl
resource "azurerm_key_vault" "trading" {
  enable_rbac_authorization   = true     # RBAC only — no legacy access policies
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true     # DORA Art. 9 — cannot hard-delete secrets
  public_network_access_enabled = false  # No public internet access

  network_acls {
    default_action = "Deny"             # Deny all by default
    bypass         = "AzureServices"    # Allow trusted Azure services only
  }
}
```
`purge_protection_enabled = true` — once enabled, it cannot be disabled. Even the subscription owner cannot hard-delete this Key Vault for 90 days. This satisfies DORA Article 9's data recoverability requirement.

`enable_rbac_authorization = true` — Azure RBAC manages who can access secrets (instead of the older Key Vault access policy model). This integrates with Azure AD, audit logs, and Conditional Access policies.

```hcl
resource "azurerm_resource_group_policy_assignment" "https_only" {
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-..."
  display_name         = "Secure transfer to storage accounts should be enabled"
  enforce              = true
}
```
Azure Policy assignment. The long GUID is the ID of a built-in Azure policy. You can find all built-in policy IDs at: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies

`enforce = true` means if someone tries to create a storage account without HTTPS-only, the creation is **denied** (not just flagged). This is the difference between auditing and preventing.

---

## 6. How to Deploy and View Output

### Deploy

```powershell
cd environments/prod
terraform init
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply tfplan
```

### View Outputs After Apply

```powershell
terraform output
```

Sample output:
```
aks_cluster_name = "trading-prod-aks"
key_vault_uri    = "https://trading-prod-kv.vault.azure.net/"
openai_endpoint  = "https://trading-prod-oai.openai.azure.com/"
search_endpoint  = "https://trading-prod-search.search.windows.net/"
```

### Verify Resources in Azure Portal

```powershell
# Get AKS credentials
az aks get-credentials --resource-group rg-trading-prod --name trading-prod-aks

# Verify cluster is running
kubectl get nodes
# Should show 3 system nodes and 3+ trading nodes, all "Ready"

# Verify node pools
kubectl get nodes --show-labels | grep workload
# trading nodes show: workload=trading

# Verify Key Vault settings
az keyvault show --name trading-prod-kv --query "{purge: properties.enablePurgeProtection, rbac: properties.enableRbacAuthorization, public: properties.publicNetworkAccess}"
# {"purge": true, "rbac": true, "public": "Disabled"}

# Verify Azure Policy is assigned
az policy assignment list --resource-group rg-trading-prod --query "[].displayName" -o table
```

### View Terraform State

```powershell
# List all resources Terraform manages
terraform state list

# Inspect a specific resource
terraform state show module.networking.azurerm_virtual_network.hub

# Visualise the dependency graph (requires Graphviz)
terraform graph | dot -Tsvg > terraform-graph.svg
```

### Check Log Analytics (Audit Logs)

```powershell
# In Azure Portal: go to Log Analytics workspace "trading-prod-law"
# Click "Logs" and run:
AzureActivity
| where TimeGenerated > ago(1h)
| where OperationNameValue contains "WRITE"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup
| order by TimeGenerated desc
```

This shows every Azure resource creation/modification in the last hour — satisfying BAIT Section 8 audit log requirements.

### Clean Up (Destroy Everything)

```powershell
terraform destroy -var-file=terraform.tfvars
```

**Note:** Key Vault will enter soft-delete state (not hard-deleted) due to `purge_protection_enabled = true`. It remains for 90 days. If you need to re-create with the same name sooner, recover it:
```powershell
az keyvault recover --name trading-prod-kv
```

---

## Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `Error: A resource with the ID "..." already exists` | Resource left over from previous run | Import it: `terraform import azurerm_resource_group.trading /subscriptions/.../resourceGroups/rg-trading-prod` |
| `Error: purge protection is enabled` on Key Vault re-creation | Previous Key Vault in soft-delete | `az keyvault recover --name trading-prod-kv` |
| `Error: The subscription ... does not have permissions` | Not Owner or Contributor on subscription | Assign Owner role: `az role assignment create --role Owner --assignee-object-id $(az ad signed-in-user show --query id -o tsv) --scope /subscriptions/YOUR-SUB-ID` |
| Slow `terraform apply` (>20 min) | AKS cluster creation takes time | Normal; AKS typically takes 8–12 minutes alone |
| `terraform state` file conflicts | Two people running apply simultaneously | Always use remote backend (configured in this project) — it has built-in locking |
