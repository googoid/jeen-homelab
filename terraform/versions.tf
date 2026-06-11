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
