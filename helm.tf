provider "kubernetes" {
  version = "~> 1.6"
}

provider "helm" {
  version            = "~> 0.9"
  enable_tls         = true
  client_key         = "${pathexpand("~/.helm/key.pem")}"
  client_certificate = "${pathexpand("~/.helm/cert.pem")}"
  ca_certificate     = "${pathexpand("~/.helm/ca.pem")}"
  insecure           = true
}

# Helm/Tiller
locals {
  helm_name        = "helm"
  helm_instance    = "${local.helm_name}-${var.env}"
  helm_version     = "v2.13.1"
  helm_part_of     = "${var.datacenter}"
  helm_managed_by  = "terraform"
  tiller_namespace = "kube-system"
}
