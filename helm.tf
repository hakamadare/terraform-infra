provider "kubernetes" {
  version = "~> 1.4"
}

provider "helm" {
  version = "~> 0.7"
}

# Helm/Tiller
locals {
  helm_name              = "helm"
  helm_instance          = "${local.helm_name}-${var.env}"
  helm_version           = "v2.12.1"
  helm_part_of           = "${var.datacenter}"
  helm_managed_by        = "terraform"
  tiller_namespace       = "${kubernetes_namespace.tiller.metadata.0.name}"
  tiller_service_account = "${kubernetes_service_account.tiller.metadata.0.name}"
}

resource "kubernetes_namespace" "tiller" {
  metadata {
    name = "tiller"

    labels {
      "app.kubernetes.io/name"       = "${local.helm_name}"
      "app.kubernetes.io/instance"   = "${local.helm_instance}"
      "app.kubernetes.io/version"    = "${local.helm_version}"
      "app.kubernetes.io/component"  = "tiller"
      "app.kubernetes.io/part-of"    = "${local.helm_part_of}"
      "app.kubernetes.io/managed-by" = "${local.helm_managed_by}"
    }
  }
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "${local.tiller_namespace}"

    labels {
      "app.kubernetes.io/name"       = "${local.helm_name}"
      "app.kubernetes.io/instance"   = "${local.helm_instance}"
      "app.kubernetes.io/version"    = "${local.helm_version}"
      "app.kubernetes.io/component"  = "tiller"
      "app.kubernetes.io/part-of"    = "${local.helm_part_of}"
      "app.kubernetes.io/managed-by" = "${local.helm_managed_by}"
    }
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"

    labels {
      "app.kubernetes.io/name"       = "${local.helm_name}"
      "app.kubernetes.io/instance"   = "${local.helm_instance}"
      "app.kubernetes.io/version"    = "${local.helm_version}"
      "app.kubernetes.io/component"  = "tiller"
      "app.kubernetes.io/part-of"    = "${local.helm_part_of}"
      "app.kubernetes.io/managed-by" = "${local.helm_managed_by}"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = "${local.tiller_service_account}"
    namespace = "${local.tiller_namespace}"
  }
}
