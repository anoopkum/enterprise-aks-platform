# GitHub Actions Setup Guide

This document describes how to configure GitHub Actions for the Enterprise AKS Platform CI/CD pipelines.

## Prerequisites

1. Azure subscription with Owner or Contributor access
2. GitHub repository with Actions enabled
3. Azure CLI installed locally for initial setup

## OIDC Federation Setup

The pipelines use OpenID Connect (OIDC) for passwordless authentication to Azure. This is more secure than using service principal secrets.

### Step 1: Create Azure AD Application

```bash
# Set variables
GITHUB_ORG="your-github-org"
GITHUB_REPO="aks-platform"
APP_NAME="github-actions-aks-platform"

# Create the application
az ad app create --display-name $APP_NAME

# Get the application ID
APP_ID=$(az ad app list --display-name $APP_NAME --query "[0].appId" -o tsv)

# Create service principal
az ad sp create --id $APP_ID

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query "id" -o tsv)
```

### Step 2: Configure Federated Credentials

Create federated credentials for each environment:

```bash
# For main branch (dev environment)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For dev environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For test environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-env-test",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:test",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For prod environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-env-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:prod",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For prod-canary environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-env-prod-canary",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':environment:prod-canary",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pull-request",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Step 3: Assign Azure RBAC Roles

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Contributor role on subscription (for Terraform)
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# User Access Administrator (for RBAC assignments)
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# AcrPush role on ACRs
for ACR in contosodevacr contosotestacr contosoprodacr; do
  az role assignment create \
    --assignee $SP_OBJECT_ID \
    --role "AcrPush" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/contoso-*-uksouth-rg-data/providers/Microsoft.ContainerRegistry/registries/$ACR"
done

# Azure Kubernetes Service Cluster Admin Role
for ENV in dev test prod; do
  az role assignment create \
    --assignee $SP_OBJECT_ID \
    --role "Azure Kubernetes Service Cluster Admin Role" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/contoso-$ENV-uksouth-rg-aks"
done
```

## GitHub Repository Configuration

### Required Secrets

Configure these secrets at the repository level (Settings → Secrets and variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AZURE_CLIENT_ID` | Azure AD Application (client) ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `12345678-1234-1234-1234-123456789012` |

### Environment-Specific Secrets

Configure these secrets at the environment level:

#### Dev Environment
| Secret Name | Description |
|-------------|-------------|
| `DEV_WORKLOAD_IDENTITY_CLIENT_ID` | Client ID for dev workload identity |

#### Test Environment
| Secret Name | Description |
|-------------|-------------|
| `TEST_WORKLOAD_IDENTITY_CLIENT_ID` | Client ID for test workload identity |

#### Prod Environment
| Secret Name | Description |
|-------------|-------------|
| `PROD_WORKLOAD_IDENTITY_CLIENT_ID` | Client ID for prod workload identity |

### GitHub Environments

Create the following environments in GitHub (Settings → Environments):

#### `dev`
- **Protection rules**: None (auto-deploy)
- **Deployment branches**: `main` only

#### `test`
- **Protection rules**: Required reviewers (1 reviewer from platform team)
- **Deployment branches**: `main` only
- **Wait timer**: 0 minutes

#### `prod-canary`
- **Protection rules**: Required reviewers (1 reviewer from platform team)
- **Deployment branches**: `main` only
- **Wait timer**: 0 minutes

#### `prod`
- **Protection rules**: Required reviewers (2 reviewers, including 1 from SRE team)
- **Deployment branches**: `main` only
- **Wait timer**: 10 minutes (for canary observation)

#### `prod-plan`
- **Protection rules**: None (plan only, no apply)
- **Deployment branches**: `main` only

## Workflow Triggers

### Terraform Pipeline (`terraform.yml`)

| Trigger | Behavior |
|---------|----------|
| Push to `main` (terraform paths) | Plan and apply dev → test → prod |
| Pull request | Plan only (all environments) |
| Manual dispatch | Select environment and action |

### Application Pipeline (`app-deploy.yml`)

| Trigger | Behavior |
|---------|----------|
| Push to `main` (src/charts paths) | Build → Deploy dev → test → prod (canary → full) |
| Pull request | Build and scan only |
| Manual dispatch | Deploy specific tag to specific environment |

## Troubleshooting

### OIDC Authentication Fails

1. Verify federated credential subject matches exactly
2. Check that the environment name in workflow matches GitHub environment
3. Ensure `id-token: write` permission is set

### Terraform State Lock

If state is locked:
```bash
az storage blob lease break \
  --account-name contosotfstate \
  --container-name tfstate \
  --blob-name dev/terraform.tfstate
```

### AKS Authentication Fails

1. Verify service principal has `Azure Kubernetes Service Cluster Admin Role`
2. Check that AKS authorized IP ranges include GitHub Actions IPs
3. Ensure kubeconfig is refreshed with `--overwrite-existing`

## Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets or Azure Key Vault
2. **Use OIDC** - Avoid long-lived service principal secrets
3. **Require approvals** - Especially for production deployments
4. **Scan images** - Trivy scans run on every build
5. **Sign images** - Enable content trust on ACR
6. **Audit logs** - Review GitHub Actions logs regularly
