# Executive Summary — Trading Azure Landing Zone

## Business Problem

Every European financial institution that moves workloads to the cloud faces the same two-stage problem:

**Stage 1 — Time to a secure environment.** Building a cloud environment that is properly architected — correct network isolation, access controls, encryption, monitoring, secret management — takes months when done from scratch by hand. Most institutions underestimate this, then rush the infrastructure to meet an application delivery deadline, and produce a result with security gaps.

**Stage 2 — Regulatory compliance.** BaFin (Germany's financial regulator) and EU regulators impose specific technical requirements on cloud infrastructure for financial institutions through BAIT (BaFin IT Supervisory Requirements) and DORA (Digital Operational Resilience Act, mandatory from January 2025). These are not audit checklist items — they are enforceable requirements. Non-compliance is a regulatory finding.

The pattern that creates the most risk: **build first, add compliance later.** Retrofitting network isolation, encryption, and audit logging onto an existing cloud environment is expensive, technically complex, and disruptive. Doing it right from the start is dramatically cheaper.

## The Solution

A complete Azure landing zone for financial trading platforms, built with Terraform and following Microsoft's Cloud Adoption Framework, with BAIT and DORA controls designed into every component from the beginning.

**The principle:** Any application deployed onto this foundation inherits compliance automatically. The application team does not need to think about network isolation, security policy enforcement, or audit logging — it is provided by the foundation.

## What This Provides (Non-Technical Summary)

**Network isolation** — The trading environment is isolated from the internet. All internet traffic is routed through an Azure Firewall that inspects and logs every connection. Administrators connect via a secure jump server (Azure Bastion) — no public SSH or remote desktop ports are exposed. This satisfies BAIT Section 5 (information security) and DORA Art. 9 (ICT risk management).

**Automatic compliance enforcement** — Azure Policy automatically prevents any team from accidentally creating a resource with public internet access. It is not possible to misconfigure a database or storage account to be publicly accessible — the policy will reject the creation attempt.

**Secret management** — API keys, database passwords, and credentials are stored in Azure Key Vault with deletion protection (cannot be accidentally deleted — DORA Art. 9), and are mounted into applications automatically without appearing in any code, configuration file, or deployment pipeline.

**Full audit trail** — Every operation performed on every resource in the environment is logged, retained for 90 days (BAIT Section 8), and available for regulator examination.

**High availability for critical systems** — The trading compute environment is distributed across 3 physically separate Azure data centres. If one fails, the platform continues operating. This satisfies DORA Art. 10 (ICT incident classification) and BAIT Section 10 (critical IT systems).

## Time to Production

| Approach | Time to Secure, Compliant Environment |
|---------- |--------------------------------------|
| Manual setup by a cloud architect | 3–6 months |
| This Terraform landing zone | 15 minutes |

The difference is not an exaggeration. Once the Terraform scripts are executed, the entire environment — networking, security, monitoring, policy, compute — is provisioned in approximately 15 minutes. The same environment, every time, with no configuration differences between runs.

## Compliance Coverage

### BAIT (BaFin)

| Section | Requirement | Status |
|---------|-------------|--------|
| Section 5 | Information security controls | Covered: Azure Policy denies public endpoints |
| Section 8 | IT operations logging (90 days) | Covered: Log Analytics workspace with retention |
| Section 10 | Critical systems availability | Covered: Multi-AZ AKS, minimum node guarantees |
| Section 11 | Cloud outsourcing controls | Covered: Private endpoints, Firewall inspection |

### DORA (EU 2022/2554, effective January 2025)

| Article | Requirement | Status |
|---------|-------------|--------|
| Art. 5 | ICT governance framework | Covered: Defender for Cloud, Policy assignments |
| Art. 9 | ICT risk management | Covered: Key Vault purge protection, GRS storage |
| Art. 10 | ICT incident classification | Covered: Azure Monitor alerts, Defender alerts |
| Art. 17 | Digital resilience testing | Covered: Separate dev/staging/prod environments |

## Cost Estimates

| Environment | Purpose | Monthly Cost |
|-------------|---------|-------------|
| Development | Developer testing | ~€400 |
| Staging | Pre-production validation | ~€900 |
| Production | Live trading platform | ~€2,500 |

These include all infrastructure components: networking, compute, AI services, security, and monitoring.

## Stakeholders

| Stakeholder | What They Gain |
|-------------|---------------|
| Chief Information Security Officer | Network isolation, policy enforcement, audit logging — from day one |
| Chief Compliance Officer | BAIT and DORA coverage documented and verifiable |
| Head of Cloud Architecture | Reusable foundation for all future projects |
| BaFin / Regulators | Documented compliance controls, available for examination |
| Application Teams | Security and compliance inherited — focus on application, not infrastructure |

## Strategic Value

This landing zone is a foundation, not a one-time project. Every future trading application the firm deploys to Azure:
- Inherits network isolation automatically
- Cannot create public-facing resources (enforced by Azure Policy)
- Has audit logs captured automatically
- Can be onboarded to the platform in days rather than months

The return on investment grows with each application deployed on top of it.

## Summary

This Terraform landing zone eliminates the most common and most expensive mistake in cloud adoption for financial services: building first and adding compliance later.

By provisioning in 15 minutes with BAIT and DORA controls built in, it removes months of infrastructure work from every project timeline and provides a single, auditable foundation that satisfies German and EU regulatory requirements.

---

*Author: Dilip Kumar Jena | IaC: Terraform 1.9 | Cloud: Azure West Europe | Regulation: BAIT, DORA, MiFID II*
