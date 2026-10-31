#local-k8s/main.tf

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kind = {
      source = "tehcyx/kind"
      version = "~> 0.9"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# 1. Local cluster (kind running inside Docker)
resource "kind_cluster" "this" {
  name           = "huggly-local"
  node_image     = "kindest/node:v1.36.1"   # match an image your kind v0.32 supportst
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      # expose a node port to localhost so you can reach ingress later
      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
      }
    }

    node {
      role = "worker"
    }
  }
}

# 2. Point the k8s + helm providers ath the kind cluster
provider "kubernetes" {
  host                  = kind_cluster.this.endpoint
  client_certificate    = kind_cluster.this.client_certificate
  client_key            = kind_cluster.this.client_key
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}

# 3. Install ArgoCD via helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.7"
  namespace  = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    configs = {
      params = { "server.insecure" = true }   # simplest for local; use port-forward
    }
  })]

  depends_on = [kind_cluster.this]
}

# 4. Read back the auto-genreated admin password as an output
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = helm_release.argocd.namespace
  }
  depends_on = [helm_release.argocd]
}

output "argocd_admin_password" {
  value     = data.kubernetes_secret.argocd_admin.data["password"]
  sensitive = true
}

output "kubeconfig_path" {
  value = kind_cluster.this.kubeconfig_path
}

