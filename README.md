# Trading Azure Landing Zone

> Enterprise-grade Azure landing zone for regulated trading platforms — Terraform IaC for AKS, Azure AI Foundry, networking, security, and compliance.

[![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)](https://terraform.io)
[![Azure](https://img.shields.io/badge/Azure-West_Europe-0089D6?logo=microsoft-azure)](https://azure.microsoft.com)
[![Compliance](https://img.shields.io/badge/Compliance-MiFID_II_BAIT-green)](https://www.bafin.de)

---

## What It Provisions

One `terraform apply` provisions a complete, regulated-ready Azure environment:

| Resource | SKU | Purpose |
|----------|-----|---------|
| AKS cluster | Standard D4s v5, 3–20 nodes | Trading microservices |
| Azure AI Foundry | Standard | Model deployment and MLOps |
| Azure AI Search | Standard S1 | RAG knowledge base |
| Azure OpenAI | Standard (GPT-4o) | AI features |
| Azure Event Hubs | Premium 4 PU | Real-time trade events |
| Azure SQL | Business Critical 8 vCore | Trade database |
| Azure Key Vault | Standard | Secrets management |
| Azure Monitor | Log Analytics | Observability |
| Azure Policy | Built-in + custom | BAIT/DORA compliance |
| Private DNS + VNet | /16 CIDR | Network isolation |

---

## Architecture

```
┌─────────────────── Azure Subscription ───────────────────────────┐
│                                                                    │
│  ┌──── Hub VNet (10.0.0.0/16) ────┐   ┌── Spoke VNet (10.1.0.0/16) ──┐ │
│  │  Azure Firewall                 │   │  AKS (system + user pools)    │ │
│  │  Bastion Host                   │◄─►│  Private Endpoints            │ │
│  │  VPN Gateway                    │   │  Azure AI Foundry             │ │
│  └─────────────────────────────────┘   │  Azure SQL (BC)               │ │
│                                        │  Event Hubs Premium           │ │
│                                        └──────────────────────────────┘ │
│                                                                    │
│  ┌── Security ─────────────────────────────────────────────────┐  │
│  │  Key Vault (RBAC, soft-delete, purge protection)            │  │
│  │  Defender for Containers                                    │  │
│  │  Azure Policy (BAIT Section 5/8/11 controls)                │  │
│  │  Azure Monitor + Log Analytics (90-day retention)           │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
# 1. Configure credentials
az login
az account set --subscription <your-subscription-id>

# 2. Initialize Terraform
cd environments/prod
terraform init

# 3. Plan
terraform plan -var-file="terraform.tfvars"

# 4. Apply
terraform apply -var-file="terraform.tfvars"
```

---

## Structure

```
trading-azure-landing-zone/
├── modules/
│   ├── aks/           ← AKS cluster with system + user node pools
│   ├── networking/    ← Hub-spoke VNet, Private DNS, Firewall
│   ├── ai-foundry/    ← AI Foundry, OpenAI, AI Search, Event Hubs
│   ├── monitoring/    ← Log Analytics, Diagnostic settings, Alerts
│   └── security/      ← Key Vault, Defender, Policy, RBAC
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .github/workflows/ ← Terraform plan/apply CI
```

---

## Compliance

- **BAIT Section 11** (IT outsourcing): All Azure services accessed via Private Endpoints
- **BAIT Section 5** (Information security): Defender for Containers, Azure Policy deny non-compliant resources
- **DORA Art. 9** (ICT risk management): Azure Backup, geo-redundant storage, Key Vault purge protection
- **MiFID II Art. 17** (IT systems): AKS Pod Disruption Budgets, multi-AZ node pools

---

## License

MIT
