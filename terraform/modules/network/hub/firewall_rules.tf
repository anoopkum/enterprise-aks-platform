# Hub Network Module - Azure Firewall Policy Rules
#
# This file creates firewall policy rule collection groups for:
# - AKS required FQDNs and network rules
# - Azure Monitor and diagnostics
# - Common infrastructure rules

#------------------------------------------------------------------------------
# AKS Required Rules - Rule Collection Group
#------------------------------------------------------------------------------

resource "azurerm_firewall_policy_rule_collection_group" "aks" {
  count = var.enable_firewall ? 1 : 0

  name               = "aks-rules"
  firewall_policy_id = azurerm_firewall_policy.main[0].id
  priority           = 100

  #----------------------------------------------------------------------------
  # Application Rules - AKS Management
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "aks-management"
    priority = 100
    action   = "Allow"

    # AKS Control Plane
    rule {
      name = "aks-control-plane"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.vnet_address_space
      destination_fqdns = ["*.hcp.${var.location}.azmk8s.io"]
    }

    # Microsoft Container Registry
    rule {
      name = "mcr"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com"
      ]
    }

    # Azure Management APIs
    rule {
      name = "azure-management"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net"
      ]
    }

    # Azure Active Directory
    rule {
      name = "azure-ad"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "login.microsoftonline.com",
        "aadcdn.msftauth.net",
        "aadcdn.msauth.net"
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Application Rules - Azure Monitor
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "azure-monitor"
    priority = 200
    action   = "Allow"

    rule {
      name = "azure-monitor-endpoints"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "dc.services.visualstudio.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com",
        "*.applicationinsights.azure.com"
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Application Rules - Azure Policy
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "azure-policy"
    priority = 300
    action   = "Allow"

    rule {
      name = "azure-policy-endpoints"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "data.policy.core.windows.net",
        "store.policy.core.windows.net"
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Application Rules - Container Images (Docker Hub, GitHub)
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "container-registries"
    priority = 400
    action   = "Allow"

    rule {
      name = "docker-hub"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "*.docker.io",
        "registry-1.docker.io",
        "production.cloudflare.docker.com",
        "auth.docker.io"
      ]
    }

    rule {
      name = "github-packages"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "ghcr.io",
        "*.ghcr.io",
        "github.com",
        "*.github.com"
      ]
    }

    rule {
      name = "quay-io"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "quay.io",
        "*.quay.io"
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Network Rules - NTP
  #----------------------------------------------------------------------------
  network_rule_collection {
    name     = "ntp"
    priority = 500
    action   = "Allow"

    rule {
      name                  = "ntp-ubuntu"
      protocols             = ["UDP"]
      source_addresses      = var.vnet_address_space
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  #----------------------------------------------------------------------------
  # Network Rules - DNS
  #----------------------------------------------------------------------------
  network_rule_collection {
    name     = "dns"
    priority = 600
    action   = "Allow"

    rule {
      name                  = "dns-azure"
      protocols             = ["UDP", "TCP"]
      source_addresses      = var.vnet_address_space
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }
  }

  #----------------------------------------------------------------------------
  # Network Rules - Azure Services
  #----------------------------------------------------------------------------
  network_rule_collection {
    name     = "azure-services"
    priority = 700
    action   = "Allow"

    rule {
      name                  = "azure-metadata"
      protocols             = ["TCP"]
      source_addresses      = var.vnet_address_space
      destination_addresses = ["169.254.169.254"]
      destination_ports     = ["80"]
    }

    rule {
      name                  = "azure-imds"
      protocols             = ["TCP"]
      source_addresses      = var.vnet_address_space
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["80", "443"]
    }
  }
}

#------------------------------------------------------------------------------
# Infrastructure Rules - Rule Collection Group
#------------------------------------------------------------------------------

resource "azurerm_firewall_policy_rule_collection_group" "infrastructure" {
  count = var.enable_firewall ? 1 : 0

  name               = "infrastructure-rules"
  firewall_policy_id = azurerm_firewall_policy.main[0].id
  priority           = 200

  #----------------------------------------------------------------------------
  # Application Rules - OS Updates
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "os-updates"
    priority = 100
    action   = "Allow"

    rule {
      name = "ubuntu-updates"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "security.ubuntu.com",
        "azure.archive.ubuntu.com",
        "changelogs.ubuntu.com",
        "archive.ubuntu.com"
      ]
    }

    rule {
      name = "microsoft-updates"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "packages.microsoft.com",
        "download.microsoft.com"
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Application Rules - Helm and Kubernetes Tools
  #----------------------------------------------------------------------------
  application_rule_collection {
    name     = "kubernetes-tools"
    priority = 200
    action   = "Allow"

    rule {
      name = "helm-charts"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "kubernetes-charts.storage.googleapis.com",
        "charts.helm.sh",
        "*.githubusercontent.com",
        "get.helm.sh"
      ]
    }

    rule {
      name = "kubernetes-registry"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = var.vnet_address_space
      destination_fqdns = [
        "registry.k8s.io",
        "*.registry.k8s.io",
        "k8s.gcr.io",
        "storage.googleapis.com"
      ]
    }
  }
}
