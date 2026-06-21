# Trading Azure Landing Zone

> **Regulation-ready Azure infrastructure for financial trading platforms — provisioned in 15 minutes via Terraform with BAIT, DORA, and MiFID II controls built in from day one.**

[![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform)](https://terraform.io)
[![Azure](https://img.shields.io/badge/Azure-West_Europe-0089D6?logo=microsoft-azure)](https://azure.microsoft.com)
[![BAIT](https://img.shields.io/badge/Compliant-BAIT_BaFin-blue)](https://www.bafin.de)
[![DORA](https://img.shields.io/badge/Compliant-DORA_EU-blue)](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32022R2554)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## The Problem

When a financial institution moves workloads to the cloud, two problems arise immediately:

**Problem 1 — Time to production.** Setting up a secure, compliant Azure environment from scratch takes months. Network architecture, security controls, identity configuration, monitoring setup, and compliance policy assignment all require specialist knowledge and are error-prone when done manually.

**Problem 2 — Regulatory compliance from the start.** German financial regulators (BaFin) and EU regulators impose specific technical requirements on cloud infrastructure through BAIT and DORA. These are not suggestions — they are mandatory controls. An institution that deploys to Azure without these controls faces regulatory action.

The most common mistake: institutions build first and bolt on compliance later. Retrofitting security controls and network isolation onto existing infrastructure is exponentially more expensive and disruptive than building them in from the start.

## The Solution

A complete, production-ready Azure landing zone for trading platforms — built on Terraform 1.9, following Microsoft's Cloud Adoption Framework, with BAIT and DORA compliance controls embedded in every module.

**Deploy once. Inherit compliance.** Every application deployed onto this foundation inherits the security controls, network isolation, and audit logging automatically.

---

## What Gets Provisioned

### Networking — Hub-Spoke Architecture

```
Hub VNet (10.0.0.0/16)                  Spoke VNet (10.1.0.0/16)
├── Azure Firewall                       ├── AKS Subnet (10.1.0.0/22)
│   (inspects all outbound traffic)      │   ├── System node pool
├── Azure Bastion                        │   └── Trading node pool (tainted)
│   (secure admin — no public SSH/RDP)   └── Services Subnet (10.1.4.0/24)
└── VPN Gateway                              └── Private Endpoints for all PaaS
    (site-to-site to on-premises)
                │
                └── VNet Peering (bidirectional)
```

**Why hub-spoke:** All traffic between the trading environment and the internet flows through the Azure Firewall in the hub. This means every outbound connection is inspected and logged — satisfying BAIT Section 5 (information security) and DORA Art. 9 (ICT risk management).

### Compute — Azure Kubernetes Service

| Node Pool | VM Size | Purpose | Taint |
|-----------|---------|---------|-------|
| system | Standard_D4s_v5 | AKS system components (DNS, metrics) | CriticalAddonsOnly |
| trading | Standard_D8s_v5 | Trading workloads | workload=trading:NoSchedule |

Two isolated pools prevent trading application bugs from affecting Kubernetes infrastructure, and prevent Kubernetes upgrades from starving trading pods of resources.

Multi-AZ deployment across 3 availability zones: if one Azure data centre fails, the platform continues operating — satisfying DORA Art. 10 (incident response) and BAIT Section 10 (critical IT systems).

### AI and Data Platform — Azure AI Foundry

| Service | SKU | Purpose |
|---------|-----|---------|
| Azure OpenAI | Standard | GPT-4o + text-embedding-3-large |
| Azure AI Search | Standard S1 | Hybrid vector + keyword search |
| Azure Event Hubs | Premium 4PU | Transaction feed, MiFID II Art. 26 reporting |

All services deployed with **private endpoints only** — no public internet access at any point.

### Security

**Azure Key Vault**
- RBAC-only access (no legacy access policies)
- Purge protection enabled (satisfies DORA Art. 9 — data cannot be accidentally deleted)
- Soft-delete: 90 days
- Private endpoint — accessible only from within the spoke VNet

**Azure Policy Assignments (BAIT compliance)**
- `Deny-PublicEndpoints` — automatically rejects any resource configured with public access
- `Require-HTTPS` — enforces TLS on all storage and web endpoints
- `Require-CMK` — enforces customer-managed keys for sensitive data stores

**Microsoft Defender for Containers**
- Runtime threat detection for all AKS workloads
- Alerts on suspicious container activity (privilege escalation, unusual network calls)

### Monitoring and Audit

| Resource | Retention | Regulatory Requirement |
|----------|-----------|----------------------|
| Log Analytics Workspace | 90 days | BAIT Section 8 |
| Azure Monitor Alerts | Ongoing | DORA Art. 10 |
| Diagnostic Settings | All resources → Log Analytics | BAIT Section 8 |
| Key Vault audit logs | 90 days | DORA Art. 9 |

---

## Compliance Matrix

### BAIT (BaFin IT Supervisory Requirements)

| Section | Requirement | Implementation |
|---------|-------------|----------------|
| Section 5 | Information security | Azure Policy: deny public endpoints |
| Section 8 | IT operations logging | Log Analytics 90-day retention, all diagnostic settings |
| Section 10 | Critical IT systems availability | Multi-AZ AKS, 3-node minimum |
| Section 11 | Cloud outsourcing controls | Private endpoints, firewall inspection, network isolation |

### DORA (Digital Operational Resilience Act, EU 2022/2554)

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| Art. 5 | ICT governance | Policy assignments, Defender for Cloud |
| Art. 9 | ICT risk management | Key Vault purge protection, GRS storage |
| Art. 10 | Incident classification | Azure Monitor alerts, Defender alerts |
| Art. 17 | Resilience testing | Separate dev/staging/prod environments |

### MiFID II

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| Art. 17 | Algo trading system availability | Multi-AZ AKS, PDB enforcement |
| Art. 26 | Transaction reporting | Event Hubs Premium, 7-day retention |

---

## Terraform Module Structure

```
trading-azure-landing-zone/
├── modules/
│   ├── networking/          ← Hub-spoke VNets, peering, subnets, Firewall, Bastion
│   ├── aks/                 ← AKS cluster, system + trading node pools, Key Vault CSI
│   ├── ai-foundry/          ← OpenAI, AI Search, Event Hubs (all private endpoint)
│   ├── security/            ← Key Vault, Defender, Azure Policy assignments
│   └── monitoring/          ← Log Analytics, diagnostic settings, alerts
└── environments/
    ├── dev/                 ← LRS storage, 1-node AKS, cheaper SKUs
    ├── staging/             ← As prod minus zone redundancy
    └── prod/                ← GRS storage, multi-AZ, purge protection, full scale
```

---

## Deployment

### Prerequisites
- Terraform 1.9+
- Azure CLI authenticated
- Subscription with Owner role

### One-Command Deploy
```bash
# 1. Create Terraform state storage (one-time setup)
az group create --name rg-terraform-state --location westeurope
az storage account create --name tfstatetrading --resource-group rg-terraform-state --sku Standard_LRS
az storage container create --name tfstate --account-name tfstatetrading

# 2. Deploy production environment (~15 minutes)
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply tfplan
```

### Environment Comparison

| Setting | dev | staging | prod |
|---------|-----|---------|------|
| AKS node count | 1 | 2 | 3 minimum |
| Storage redundancy | LRS | ZRS | GRS (geo-redundant) |
| Key Vault purge protection | No | No | Yes (mandatory) |
| Availability zones | 1 | 1,2 | 1,2,3 |
| Monthly estimated cost | ~€400 | ~€900 | ~€2,500 |

---

## Secret Management Flow

```
Terraform creates secrets → Azure Key Vault (private endpoint only)
                                    │
                                    ▼
                    AKS Key Vault CSI Driver
                    (rotates secrets every 2 minutes automatically)
                                    │
                                    ▼
                    Mounted as read-only volume in pods
                    (never as environment variables)
                                    │
                                    ▼
                    Application reads from /mnt/secrets/
```

Secrets never appear in:
- Helm values files (committed to Git)
- Kubernetes Secret manifests
- Container environment variables
- CI/CD pipeline logs
- Docker image layers

---

## Business Value

| Challenge | Before (Manual) | After (This Landing Zone) |
|-----------|----------------|--------------------------|
| Time to compliant Azure environment | 3–6 months | 15 minutes |
| BAIT/DORA compliance | Retrofitted, expensive | Built in from day one |
| Consistency across environments | Manual, error-prone | Terraform ensures identical structure |
| Security policy enforcement | Periodic audits | Azure Policy enforces automatically |
| New project onboarding | Months of infrastructure work | Deploy on top of existing foundation |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Executive Summary](docs/EXECUTIVE_SUMMARY.md) | Business case, compliance value, cost analysis |
| [Architecture Guide](docs/ARCHITECTURE.md) | Hub-spoke design, compliance controls, secret management |
| [Deployment Guide](docs/DEPLOYMENT.md) | Terraform setup, environment differences, CI/CD |

---

## About

Built to demonstrate enterprise Azure landing zone design for regulated financial services, targeting Cloud Architect, Principal Architect, and Infrastructure Lead roles at European financial institutions subject to BaFin (BAIT) and EU (DORA, MiFID II) regulation.

**Author:** Dilip Kumar Jena | **IaC:** Terraform 1.9 | **Regulation:** BAIT, DORA, MiFID II
