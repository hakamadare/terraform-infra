provider "kubernetes" {
  version = "~> 1.4"
}

provider "helm" {
  version = "~> 0.7"
}

# Helm/Tiller
locals {
  helm_name        = "helm"
  helm_instance    = "${local.helm_name}-${var.env}"
  helm_version     = "v2.12.1"
  helm_part_of     = "${var.datacenter}"
  helm_managed_by  = "terraform"
  tiller_namespace = "kube-system"
}
