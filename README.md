# Enterprise AKS Platform

Production-ready Azure Kubernetes Service (AKS) infrastructure following enterprise best practices and Zero Trust security principles.

## 🏗️ Architecture

This platform implements a hub-spoke network topology with:

- **Private AKS Cluster** with Azure AD integration
- **Azure Firewall** for egress control
- **Azure Bastion** for secure access
- **Private Endpoints** for all PaaS services
- **OPA Gatekeeper** for policy enforcement
- **Prometheus/Grafana** for monitoring
- **KEDA** for event-driven autoscaling

## 📁 Project Structure

```
├── terraform/
│   ├── modules/           # Reusable Terraform modules
│   │   ├── aks/          # AKS cluster configuration
│   │   ├── network/      # Hub and spoke networks
│   │   ├── security/     # Key Vault, managed identities
│   │   ├── data/         # ACR, PostgreSQL, Storage
│   │   ├── observability/# Log Analytics, App Insights
│   │   └── governance/   # Azure Policy, budgets
│   └── environments/     # Environment configurations
│       ├── dev/
│       ├── test/
│       └── prod/
├── kubernetes/           # Kubernetes manifests
│   ├── gatekeeper/      # OPA policies
│   ├── monitoring/      # Prometheus, Grafana
│   ├── keda/           # Autoscaling examples
│   └── velero/         # Backup configuration
├── charts/              # Helm charts
│   └── myapp/          # Application template
├── .github/workflows/   # CI/CD pipelines
└── docs/               # Documentation
```

## 🚀 Quick Start

### Prerequisites

- Azure CLI (`az`) authenticated
- Terraform >= 1.5
- kubectl
- Helm 3.x
- GitHub CLI (`gh`) for CI/CD setup

### 1. Create Backend Storage

```bash
bash terraform/scripts/init-backend.sh dev
```

### 2. Configure Variables

Edit `terraform/environments/dev/terraform.tfvars` with your values.

### 3. Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 4. Configure kubectl

```bash
az aks get-credentials -g <resource-group> -n <cluster-name>
```

## 🔐 Security Features

- **Private Cluster**: API server not exposed to internet
- **Azure AD Integration**: No local accounts
- **Workload Identity**: Credential-free pod authentication
- **Network Policies**: Pod-to-pod traffic control
- **OPA Gatekeeper**: Admission control policies
- **Key Vault Integration**: Secrets Store CSI Driver

## 📊 Monitoring

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and visualization
- **Azure Monitor**: Container Insights
- **Application Insights**: Distributed tracing

## 📖 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Autoscaling Guide](docs/AUTOSCALING.md)
- [Disaster Recovery](docs/DISASTER_RECOVERY.md)
- [Resilience Patterns](docs/RESILIENCE.md)
- [GitHub Setup](docs/GITHUB_SETUP.md)
- [Troubleshooting](docs/runbooks/TROUBLESHOOTING.md)
- [Incident Response](docs/runbooks/INCIDENT_RESPONSE.md)

## 🔄 CI/CD

This project uses GitHub Actions with OIDC authentication for secure, credential-free deployments.

### Pipelines

- **terraform.yml**: Infrastructure deployment (dev → test → prod)
- **app-deploy.yml**: Application build and deployment with canary releases

See [GitHub Setup Guide](docs/GITHUB_SETUP.md) for configuration instructions.

## 📝 License

MIT License - See [LICENSE](LICENSE) for details.

## 👥 Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📧 Contact

Owner: anoop.kumar@rackspace.com
