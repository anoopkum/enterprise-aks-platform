#!/bin/bash
#
# Initialize Terraform Backend Storage Account
#
# This script creates the Azure Storage Account for Terraform state management
# with the following features:
# - GRS (Geo-Redundant Storage) replication
# - Blob versioning enabled
# - Soft delete enabled (7 days retention)
# - Blob lease for state locking
# - HTTPS-only access
# - TLS 1.2 minimum
#
# Usage: ./init-backend.sh <environment>
# Example: ./init-backend.sh dev

set -euo pipefail

# Configuration - Update these for your organization
ORG="enterprise"
REGION="uksouth"
ENV="${1:-dev}"

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, test, prod"
    echo "Usage: $0 <environment>"
    exit 1
fi

# Resource names (storage account names must be 3-24 chars, lowercase alphanumeric only)
RESOURCE_GROUP="rg-${ORG}-${ENV}-tfstate"
# Create a unique storage account name (max 24 chars)
RANDOM_SUFFIX=$(echo $RANDOM | md5sum | head -c 6)
STORAGE_ACCOUNT="${ORG}${ENV}tfstate${RANDOM_SUFFIX}"
CONTAINER_NAME="tfstate"

echo "=============================================="
echo "Terraform Backend Initialization"
echo "=============================================="
echo "Environment:     ${ENV}"
echo "Resource Group:  ${RESOURCE_GROUP}"
echo "Storage Account: ${STORAGE_ACCOUNT}"
echo "Container:       ${CONTAINER_NAME}"
echo "Region:          ${REGION}"
echo "=============================================="
echo ""

# Check if logged in to Azure
echo "Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
    echo "Error: Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Using subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"
echo ""

# Confirm before proceeding
read -p "Do you want to create the backend storage? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Creating resource group..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${REGION}" \
    --tags Environment="${ENV}" ManagedBy="terraform-backend" Application="aks-platform" Owner="anoop.kumar@rackspace.com" \
    --output none

echo "Creating storage account..."
az storage account create \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${REGION}" \
    --sku Standard_GRS \
    --kind StorageV2 \
    --access-tier Hot \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access true \
    --tags Environment="${ENV}" ManagedBy="terraform-backend" Application="aks-platform" Owner="anoop.kumar@rackspace.com" \
    --output none

echo "Enabling blob versioning..."
az storage account blob-service-properties update \
    --account-name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --enable-versioning true \
    --output none

echo "Enabling soft delete for blobs (7 days)..."
az storage account blob-service-properties update \
    --account-name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --enable-delete-retention true \
    --delete-retention-days 7 \
    --output none

echo "Enabling soft delete for containers (7 days)..."
az storage account blob-service-properties update \
    --account-name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --enable-container-delete-retention true \
    --container-delete-retention-days 7 \
    --output none

echo "Creating blob container..."
az storage container create \
    --name "${CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none

echo ""
echo "=============================================="
echo "Backend Storage Created Successfully!"
echo "=============================================="
echo ""
echo "Update your backend.tf files with these values:"
echo ""
echo "  resource_group_name  = \"${RESOURCE_GROUP}\""
echo "  storage_account_name = \"${STORAGE_ACCOUNT}\""
echo "  container_name       = \"${CONTAINER_NAME}\""
echo "  key                  = \"${ENV}/aks-platform.tfstate\""
echo ""
echo "=============================================="
echo ""
echo "IMPORTANT: Save these values! You'll need them for backend.tf"
echo ""
echo "# Export for Terraform (run these commands):"
echo "export ARM_TENANT_ID=\"${TENANT_ID}\""
echo "export ARM_SUBSCRIPTION_ID=\"${SUBSCRIPTION_ID}\""
echo ""
echo "# For local development (using Azure CLI auth):"
echo "export ARM_USE_CLI=true"
echo ""
echo "Then run: cd terraform/environments/${ENV} && terraform init"
echo "=============================================="
