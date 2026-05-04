# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please follow these steps:

1. **Do NOT** create a public GitHub issue for the vulnerability
2. Send an email to anoop.kumar@rackspace.com with:
   - A description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact of the vulnerability
   - Any suggested fixes (if available)

## Security Measures

This repository implements the following security measures:

### GitHub Advanced Security

- **Code Scanning (CodeQL)**: Automated code analysis to find security vulnerabilities
- **Secret Scanning**: Detects secrets accidentally committed to the repository
- **Push Protection**: Prevents pushing commits containing secrets
- **Dependency Review**: Reviews dependencies for known vulnerabilities on PRs

### Infrastructure as Code Security

- **Checkov**: Policy-as-code for Terraform and Kubernetes
- **tfsec**: Terraform-specific security scanner
- **Trivy**: Comprehensive vulnerability scanner for IaC
- **KICS**: Keeping Infrastructure as Code Secure
- **Kubesec**: Kubernetes manifest security analysis

### Dependency Management

- **Dependabot**: Automated dependency updates
- **Dependency Review Action**: Blocks PRs with vulnerable dependencies

## Security Best Practices

When contributing to this repository:

1. **Never commit secrets** - Use environment variables or secret management tools
2. **Follow least privilege** - Request only necessary permissions
3. **Keep dependencies updated** - Review and merge Dependabot PRs promptly
4. **Review security alerts** - Address findings in the Security tab
5. **Use signed commits** - Enable GPG signing for commits

## Security Scanning Schedule

| Scanner | Frequency |
|---------|-----------|
| CodeQL | On push, PR, weekly |
| Checkov | On push, PR, daily |
| Trivy | On push, PR, daily |
| Secret Scanning | Continuous |
| Dependency Review | On PR |

## Compliance

This infrastructure is designed with the following compliance frameworks in mind:

- CIS Azure Kubernetes Service Benchmark
- Azure Security Benchmark
- NIST 800-53
- SOC 2 Type II

## Contact

For security-related questions, contact: anoop.kumar@rackspace.com
