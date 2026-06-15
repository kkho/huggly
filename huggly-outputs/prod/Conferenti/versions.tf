# Common/versions.tf.scriban

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }

    azuredevops = {
      source = "microsoft/azuredevops"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }

    google = {
      source = "hashicorp/google"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    tfe = {
      source = "hashicorp/tfe"
    }

    time = {
      source = "hashicorp/time"
    }

    tls = {
      source = "hashicorp/tls"
    }

    null = {
      source = "hashicorp/null"
    }

    required_version = ">= 1.0.0"
  }
}
