locals {
  reloader_name          = "reloader"
  reloader_namespace     = local.reloader_name
  reloader_instance      = "${local.reloader_name}-${var.env}"
  reloader_version       = "v0.0.25"
  reloader_part_of       = var.datacenter
  reloader_managed_by    = "terraform"
  reloader_wait          = false
  reloader_force_update  = false
  reloader_recreate_pods = false
}

data "template_file" "reloader_values" {
  template = file("${path.module}/templates/reloader-values.yaml.tpl")

  vars = {
    version = local.reloader_version
  }
}

resource "kubernetes_namespace" "reloader" {
  metadata {
    name = local.reloader_name

    labels = {
      "app.kubernetes.io/component"  = "reloader"
      "app.kubernetes.io/instance"   = local.reloader_instance
      "app.kubernetes.io/managed-by" = local.reloader_managed_by
      "app.kubernetes.io/name"       = local.reloader_name
      "app.kubernetes.io/part-of"    = local.reloader_part_of
      "app.kubernetes.io/version"    = local.reloader_version
    }
  }
}

resource "helm_release" "reloader" {
  name          = local.reloader_name
  namespace     = local.reloader_namespace
  chart         = "${path.module}/helm/reloader"
  wait          = local.reloader_wait
  force_update  = local.reloader_force_update
  recreate_pods = local.reloader_recreate_pods

  values = [
    data.template_file.reloader_values.rendered,
  ]

  depends_on = [kubernetes_namespace.reloader]
}

