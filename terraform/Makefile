# Enterprise AKS Platform - Terraform Makefile
# Common commands for managing Terraform infrastructure

.PHONY: help init plan apply destroy fmt validate lint docs clean init-backend

# Default environment
ENV ?= dev

# Terraform directories
TF_DIR := environments/$(ENV)
MODULES_DIR := modules

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "Enterprise AKS Platform - Terraform Commands"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|test|prod]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make init ENV=dev      # Initialize dev environment"
	@echo "  make plan ENV=prod     # Plan changes for production"
	@echo "  make apply ENV=test    # Apply changes to test"

init: ## Initialize Terraform for the specified environment
	@echo "$(BLUE)Initializing Terraform for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform init -upgrade
	@echo "$(GREEN)Initialization complete!$(NC)"

plan: ## Generate and show an execution plan
	@echo "$(BLUE)Planning Terraform changes for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform plan -out=tfplan
	@echo "$(GREEN)Plan saved to $(TF_DIR)/tfplan$(NC)"

apply: ## Apply the Terraform plan
	@echo "$(YELLOW)Applying Terraform changes for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform apply tfplan
	@echo "$(GREEN)Apply complete!$(NC)"

apply-auto: ## Apply changes without confirmation (use with caution)
	@echo "$(RED)Auto-applying Terraform changes for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)Apply complete!$(NC)"

destroy: ## Destroy all infrastructure (use with extreme caution)
	@echo "$(RED)WARNING: This will destroy all infrastructure in $(ENV)!$(NC)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ]
	@cd $(TF_DIR) && terraform destroy
	@echo "$(GREEN)Destroy complete!$(NC)"

fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive .
	@echo "$(GREEN)Formatting complete!$(NC)"

fmt-check: ## Check Terraform formatting without making changes
	@echo "$(BLUE)Checking Terraform formatting...$(NC)"
	@terraform fmt -recursive -check . || (echo "$(RED)Formatting issues found. Run 'make fmt' to fix.$(NC)" && exit 1)
	@echo "$(GREEN)All files properly formatted!$(NC)"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform validate
	@echo "$(GREEN)Validation successful!$(NC)"

lint: ## Run tflint on all modules
	@echo "$(BLUE)Running tflint on modules...$(NC)"
	@for dir in $(MODULES_DIR)/*/; do \
		echo "Linting $$dir..."; \
		cd $$dir && tflint --init && tflint && cd -; \
	done
	@echo "$(GREEN)Linting complete!$(NC)"

security-scan: ## Run security scanning with checkov
	@echo "$(BLUE)Running security scan with checkov...$(NC)"
	@checkov -d . --framework terraform --quiet
	@echo "$(GREEN)Security scan complete!$(NC)"

docs: ## Generate documentation for modules
	@echo "$(BLUE)Generating module documentation...$(NC)"
	@for dir in $(MODULES_DIR)/*/; do \
		echo "Generating docs for $$dir..."; \
		terraform-docs markdown table $$dir > $$dir/README.md; \
	done
	@echo "$(GREEN)Documentation generated!$(NC)"

clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	@find . -name "*.tfplan" -delete
	@find . -name "tfplan" -delete
	@find . -name ".terraform.lock.hcl" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

output: ## Show Terraform outputs for the environment
	@echo "$(BLUE)Showing outputs for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform output

state-list: ## List resources in Terraform state
	@echo "$(BLUE)Listing state for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform state list

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing state for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform refresh
	@echo "$(GREEN)Refresh complete!$(NC)"

init-backend: ## Initialize backend storage account (run once per subscription)
	@echo "$(BLUE)Creating backend storage for Terraform state...$(NC)"
	@./scripts/init-backend.sh $(ENV)
	@echo "$(GREEN)Backend initialization complete!$(NC)"

unlock: ## Unlock Terraform state (use when state is locked)
	@echo "$(YELLOW)Unlocking Terraform state for $(ENV) environment...$(NC)"
	@read -p "Enter lock ID: " lock_id && cd $(TF_DIR) && terraform force-unlock $$lock_id

graph: ## Generate a visual graph of Terraform resources
	@echo "$(BLUE)Generating resource graph for $(ENV) environment...$(NC)"
	@cd $(TF_DIR) && terraform graph | dot -Tpng > graph.png
	@echo "$(GREEN)Graph saved to $(TF_DIR)/graph.png$(NC)"

# CI/CD specific targets
ci-init: ## Initialize for CI/CD (no color, compact output)
	@cd $(TF_DIR) && terraform init -input=false -no-color

ci-plan: ## Plan for CI/CD with JSON output
	@cd $(TF_DIR) && terraform plan -input=false -no-color -out=tfplan
	@cd $(TF_DIR) && terraform show -json tfplan > tfplan.json

ci-apply: ## Apply for CI/CD (auto-approve)
	@cd $(TF_DIR) && terraform apply -input=false -no-color -auto-approve tfplan
