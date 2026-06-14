# Deployment Guide

## Prerequisites

- Terraform 1.9+
- Azure CLI authenticated (`az login`)
- Subscription with Owner role

## First-Time Setup (Terraform State)

```bash
# Create storage account for Terraform state
az group create --name rg-terraform-state --location westeurope
az storage account create --name tfstatetrading --resource-group rg-terraform-state --sku Standard_LRS
az storage container create --name tfstate --account-name tfstatetrading
```

## Deploy Production

```bash
cd environments/prod

# Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit: subscription_id, location

# Init (downloads providers, configures remote state)
terraform init

# Plan (review what will be created)
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply (~15 minutes)
terraform apply tfplan
```

## Environment Differences

| Setting | dev | staging | prod |
|---------|-----|---------|------|
| AKS node count | 1 | 2 | 3 (min) |
| Storage redundancy | LRS | ZRS | GRS |
| Key Vault purge protection | false | false | true |
| AKS zones | 1 | 1,2 | 1,2,3 |
| OpenAI capacity (TPM) | 10K | 20K | 30K |

## CI/CD (GitHub Actions)

Terraform plan runs on every PR. Apply runs on merge to `main` with GitHub Environment approval gate.

```
PR opened → terraform plan (comment on PR)
         → manual approval required
         ↓
Merged to main → terraform apply
```

Secrets stored in GitHub Secrets:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

## Destroy (dev/staging only)

```bash
cd environments/dev
terraform destroy -var-file=terraform.tfvars
```

**Never run `terraform destroy` on prod** — Key Vault purge protection and resource group deletion lock prevent accidental destruction.
