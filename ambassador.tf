locals {
  ambassador_name          = "ambassador"
  ambassador_repo_url      = "https://www.getambassador.io"
  ambassador_instance      = "${local.ambassador_name}-${var.env}"
  ambassador_version       = "0.40.2"
  ambassador_part_of       = "${var.datacenter}"
  ambassador_managed_by    = "terraform"
  ambassador_wait          = false
  ambassador_force_update  = false
  ambassador_recreate_pods = true
  ambassador_daemonset     = true

  ambassador_namespaces = [
    "default",
  ]
}

data "template_file" "ambassador_values" {
  template = "${file("${path.module}/templates/ambassador-values.yaml.tpl")}"

  vars {
    name      = "${local.ambassador_name}"
    env       = "${var.env}"
    version   = "${local.ambassador_version}"
    daemonset = "${local.ambassador_daemonset}"
  }
}

resource "helm_repository" "datawire" {
  name = "datawire"
  url  = "${local.ambassador_repo_url}"
}

resource "helm_release" "ambassador" {
  count         = "${length(local.ambassador_namespaces)}"
  name          = "${local.ambassador_name}-${local.ambassador_namespaces[count.index]}"
  namespace     = "${local.ambassador_namespaces[count.index]}"
  chart         = "${path.module}/helm/ambassador"
  wait          = "${local.ambassador_wait}"
  force_update  = "${local.ambassador_force_update}"
  recreate_pods = "${local.ambassador_recreate_pods}"

  values = [
    "${data.template_file.ambassador_values.rendered}",
  ]

  depends_on = [
    "helm_repository.datawire",
  ]
}
