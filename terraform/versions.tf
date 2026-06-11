terraform {
  required_version = ">= 1.6"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.8"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
