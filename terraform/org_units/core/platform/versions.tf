terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.4.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    argocd = {
      source = "oboukili/argocd"
      version = "6.0.3"
    }
    htpasswd = {
      source = "loafoe/htpasswd"
    }
  }
  required_version = ">= 1.4.1"
}

