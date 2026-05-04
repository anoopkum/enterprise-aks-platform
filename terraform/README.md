# Enterprise AKS Platform - Terraform Infrastructure

This repository contains the Terraform Infrastructure as Code (IaC) for the Enterprise AKS Platform. The platform implements a production-ready, highly secure, scalable, and cost-optimized Azure Kubernetes Service (AKS) solution following Zero Trust principles.

## Directory Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── network/
│   │   ├── hub/               # Hub network (Firewall, Bastion, DNS)
│   │   └── spoke/             # Spoke network (AKS subnets, peering)
│   ├── aks/                   # AKS cluster and node pools
│   ├── security/              # Key Vault, managed identities, private endpoints
│   ├── observability/         # Log Analytics, App Insights, alerts
│   ├── data/                  # ACR, PostgreSQL, Storage
│   └── governance/            # Azure Policy, budgets
├── environments/              # Environment-specific configurations
│   ├── dev/                   # Development environment
│   ├── test/                  # Test environment
│   └── prod/                  # Production environment
└── shared/                    # Shared configurations (naming, tags)
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50.0
- Azure subscription with appropriate permissions
- Service Principal or Managed Identity for CI/CD (OIDC recommended)

## Naming Convention

All resources follow the naming pattern:
```
{org}-{env}-{region}-{resource-type}-{instance}
```

Example: `contoso-prod-eastus-aks-main`

## Mandatory Tags

All resources are tagged with:
- `Environment` - dev, test, prod
- `Owner` - Team or individual email
- `CostCenter` - Cost allocation code
- `Application` - Application name
- `ManagedBy` - terraform
- `Repository` - Source repository URL
- `CreatedDate` - Resource creation timestamp

## Quick Start

### 1. Initialize Backend (First Time Only)

```bash
# Create the storage account for Terraform state
make init-backend ENV=dev
```

### 2. Initialize Terraform

```bash
# Initialize Terraform for a specific environment
make init ENV=dev
```

### 3. Plan Changes

```bash
# Preview changes for an environment
make plan ENV=dev
```

### 4. Apply Changes

```bash
# Apply changes to an environment
make apply ENV=dev
```

## Available Make Commands

| Command | Description |
|---------|-------------|
| `make init ENV=<env>` | Initialize Terraform for an environment |
| `make plan ENV=<env>` | Generate execution plan |
| `make apply ENV=<env>` | Apply changes |
| `make destroy ENV=<env>` | Destroy infrastructure |
| `make fmt` | Format all Terraform files |
| `make validate ENV=<env>` | Validate configuration |
| `make lint` | Run tflint on all modules |
| `make docs` | Generate documentation |
| `make clean` | Clean up temporary files |

## Environment Variables

For CI/CD pipelines using OIDC authentication:

```bash
export ARM_USE_OIDC=true
export ARM_CLIENT_ID="<service-principal-client-id>"
export ARM_TENANT_ID="<azure-tenant-id>"
export ARM_SUBSCRIPTION_ID="<azure-subscription-id>"
```

For local development with Azure CLI:

```bash
az login
az account set --subscription "<subscription-name-or-id>"
```

## Module Documentation

Each module contains its own README.md with:
- Input variables
- Output values
- Usage examples
- Dependencies

## Security Considerations

- All PaaS services use Private Endpoints
- AKS cluster is private with authorized IP ranges for developer access
- Secrets are stored in Azure Key Vault
- Workload Identity is used for pod authentication
- Azure Firewall controls all egress traffic

## Contributing

1. Create a feature branch
2. Make changes and run `make fmt` and `make validate`
3. Submit a pull request
4. CI pipeline will run security scans and plan

## License

Copyright © 2024 Contoso. All rights reserved.
