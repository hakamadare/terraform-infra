locals {
  cert_manager_name            = "cert-manager"
  cert_manager_instance        = "${local.cert_manager_name}-${var.env}"
  cert_manager_version         = "v0.5.2"
  cert_manager_part_of         = "${var.datacenter}"
  cert_manager_managed_by      = "terraform"
  cert_manager_wait            = false
  cert_manager_force_update    = false
  cert_manager_recreate_pods   = true
  cert_manager_namespace       = "${local.cert_manager_name}"
  cert_manager_service_account = "${local.cert_manager_name}"
}

data "template_file" "cert_manager_values" {
  template = "${file("${path.module}/templates/cert-manager-values.yaml.tpl")}"

  vars {
    name            = "${local.cert_manager_name}"
    env             = "${var.env}"
    version         = "${local.cert_manager_version}"
    service_account = "${local.cert_manager_service_account}"
    namespace       = "${local.cert_manager_namespace}"
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "${local.cert_manager_name}"

    labels {
      "app.kubernetes.io/name"       = "${local.cert_manager_name}"
      "app.kubernetes.io/instance"   = "${local.cert_manager_instance}"
      "app.kubernetes.io/version"    = "${local.cert_manager_version}"
      "app.kubernetes.io/component"  = "cert-manager"
      "app.kubernetes.io/part-of"    = "${local.cert_manager_part_of}"
      "app.kubernetes.io/managed-by" = "${local.cert_manager_managed_by}"
    }
  }
}

resource "helm_release" "cert_manager" {
  name          = "${local.cert_manager_name}"
  namespace     = "${local.cert_manager_namespace}"
  version       = "0.1.0"
  chart         = "${path.module}/helm/cert-manager"
  wait          = "${local.cert_manager_wait}"
  force_update  = "${local.cert_manager_force_update}"
  recreate_pods = "${local.cert_manager_recreate_pods}"

  values = [
    "${data.template_file.cert_manager_values.rendered}",
  ]
}
