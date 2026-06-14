# Trading Azure Landing Zone — Architecture

## Overview

A complete, regulated-ready Azure landing zone for trading platforms — provisioned via Terraform with hub-spoke networking, private endpoints throughout, and built-in controls for BAIT, DORA, and MiFID II.

---

## Landing Zone Design

```
┌─────────────────────────────── Azure Subscription ────────────────────────────────────┐
│                                                                                        │
│  ┌─────── Management Layer ──────────────────────────────────────────────────────┐    │
│  │  Log Analytics Workspace (90-day retention — BAIT Section 8)                  │    │
│  │  Azure Monitor + Diagnostic Settings (all resources → Log Analytics)          │    │
│  │  Azure Policy (BAIT Section 5/11 — deny public endpoints, enforce HTTPS)      │    │
│  │  Microsoft Defender for Containers                                             │    │
│  └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
│  ┌─────── Hub VNet (10.0.0.0/16) ───────────────────────────────────────────────┐    │
│  │  Azure Firewall (outbound traffic inspection)                                 │    │
│  │  Azure Bastion (secure admin access — no public SSH/RDP)                     │    │
│  │  VPN Gateway (site-to-site to on-premises trading systems)                   │    │
│  └────────────────────────────────────────────────────────────────────────────────┘   │
│               │ VNet Peering (bidirectional, forwarded traffic)                        │
│  ┌─────── Spoke VNet (10.1.0.0/16) ────────────────────────────────────────────┐    │
│  │                                                                               │    │
│  │  ┌── AKS Subnet (10.1.0.0/22) ──┐   ┌── Services Subnet (10.1.4.0/24) ──┐  │    │
│  │  │  System node pool (3 nodes)   │   │  Private Endpoints:                │  │    │
│  │  │  User node pool (3–20 nodes)  │   │    ├── Azure OpenAI                │  │    │
│  │  │  Azure CNI networking         │   │    ├── Azure AI Search             │  │    │
│  │  │  Calico network policy        │   │    ├── Azure SQL                   │  │    │
│  │  │  Multi-AZ (zones 1/2/3)       │   │    ├── Event Hubs                  │  │    │
│  │  └───────────────────────────────┘   │    └── Storage Account            │  │    │
│  │                                       └───────────────────────────────────┘  │    │
│  │  ┌── Key Vault ───────────────────────────────────────────────────────────┐  │    │
│  │  │  RBAC-only (no access policies)  │  Purge protection (DORA Art. 9)    │  │    │
│  │  │  Soft-delete 90 days             │  Private endpoint only              │  │    │
│  │  └────────────────────────────────────────────────────────────────────────┘  │    │
│  └───────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Terraform Module Structure

```
trading-azure-landing-zone/
├── modules/
│   ├── networking/     ← Hub-spoke VNets, peering, subnets
│   ├── aks/            ← AKS cluster + node pools (system + trading)
│   ├── ai-foundry/     ← Azure OpenAI, AI Search, Event Hubs
│   ├── security/       ← Key Vault, Defender, Azure Policy
│   └── monitoring/     ← Log Analytics, diagnostic settings, alerts
└── environments/
    ├── dev/            ← LRS storage, 1 AKS replica, cheaper SKUs
    ├── staging/        ← As prod minus HA
    └── prod/           ← GRS storage, multi-AZ AKS, purge protection
```

---

## Compliance Controls by Regulation

### BAIT (BaFin IT supervisory requirements)

| Section | Control | Implementation |
|---------|---------|----------------|
| Section 5 — Information security | Deny public endpoints | Azure Policy assignment |
| Section 8 — IT operations | Audit logging | 90-day Log Analytics retention |
| Section 10 — Critical IT systems | High availability | Multi-AZ AKS node pools |
| Section 11 — IT outsourcing (cloud) | Network isolation | All services via Private Endpoints only |

### DORA (Digital Operational Resilience Act)

| Article | Control | Implementation |
|---------|---------|----------------|
| Art. 9 — ICT risk management | Data recoverability | Key Vault purge protection, GRS storage |
| Art. 10 — Incident classification | Monitoring | Azure Monitor alerts, Defender for Containers |
| Art. 17 — Resilience testing | Test environments | Separate dev/staging/prod with Terraform workspaces |

### MiFID II

| Article | Control | Implementation |
|---------|---------|----------------|
| Art. 17 — Algorithmic trading controls | System availability | AKS Pod Disruption Budgets, multi-AZ |
| Art. 26 — Transaction reporting | Audit trail | Event Hubs Premium (7-day retention) |

---

## AKS Node Pool Design

Two node pools, isolated by taint/toleration:

| Pool | VM | Purpose | Taint |
|------|----|---------|-------|
| `system` | Standard_D4s_v5 | AKS system components only | `CriticalAddonsOnly` |
| `trading` | Standard_D8s_v5 | Trading workloads | `workload=trading:NoSchedule` |

This prevents trading pods from competing with DNS/CoreDNS/metrics-server for resources.

---

## Secret Management Flow

```
Terraform creates secrets → Azure Key Vault
        │
        ▼
AKS Key Vault CSI Driver (secret rotation every 2 min)
        │
        ▼
Mounted as volume in pods (never as env vars in manifests)
        │
        ▼
App reads from /mnt/secrets/ at startup
```

Secrets never appear in:
- Helm values files
- Kubernetes manifests (in Git)
- Container environment variables (in Docker layer)
- CI/CD logs

---

## References

### Terraform
- [Terraform Azure provider docs (azurerm)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform docs — modules](https://developer.hashicorp.com/terraform/language/modules)
- [YouTube: Terraform on Azure complete tutorial (TechWorld with Nana, 3h)](https://www.youtube.com/watch?v=V53AHWun17s)
- [YouTube: Terraform best practices (HashiConf 2023)](https://www.youtube.com/watch?v=gxPykhPxRW0)

### Azure Hub-Spoke Networking
- [Azure docs — Hub-spoke network topology](https://learn.microsoft.com/en-us/azure/architecture/networking/architecture/hub-spoke)
- [Azure docs — Private endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure docs — Azure Firewall](https://learn.microsoft.com/en-us/azure/firewall/overview)

### Azure Key Vault
- [Azure Key Vault docs](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
- [AKS Key Vault CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)

### Compliance Regulations
- [BAIT — BaFin IT-Aufsichtsanforderungen (full text, German)](https://www.bafin.de/SharedDocs/Veroeffentlichungen/DE/Rundschreiben/2021/rs_10_2021_BAIT.html)
- [DORA — Digital Operational Resilience Act (EUR-Lex)](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32022R2554)
- [Azure compliance for financial services (Microsoft)](https://learn.microsoft.com/en-us/azure/compliance/offerings/offering-bafin-germany)
- [YouTube: DORA compliance explained (FS-ISAC, 30 min)](https://www.youtube.com/watch?v=W_5RgBBT8RI)

### Azure Landing Zone Reference Architecture
- [Azure Landing Zone docs (Cloud Adoption Framework)](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Architecture Center — financial services](https://learn.microsoft.com/en-us/azure/architecture/industries/finance)
