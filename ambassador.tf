locals {
  ambassador_name             = "ambassador"
  ambassador_repo_url         = "https://www.getambassador.io"
  ambassador_instance         = "${local.ambassador_name}-${var.env}"
  ambassador_version          = "v0.73.0"
  ambassador_part_of          = "${var.datacenter}"
  ambassador_managed_by       = "terraform"
  ambassador_wait             = false
  ambassador_force_update     = false
  ambassador_recreate_pods    = false
  ambassador_daemonset        = true
  ambassador_tls_commonname   = "vecna.org"
  ambassador_tls_secret       = "ambassador-certs"
  ambassador_acme_issuer      = "letsencrypt-prod"
  ambassador_acme_issuer_kind = "ClusterIssuer"
  ambassador_acme_provider    = "route53"

  ambassador_namespaces = [
    "default",
  ]

  ambassador_fqdns = [
    "static-someguyontheinternet.vecna.org",
  ]

  ambassador_fqdns_string = "${join(",", local.ambassador_fqdns)}"
}

data "template_file" "ambassador_values" {
  template = "${file("${path.module}/templates/ambassador-values.yaml.tpl")}"

  vars {
    name             = "${local.ambassador_name}"
    env              = "${var.env}"
    version          = "${local.ambassador_version}"
    daemonset        = "${local.ambassador_daemonset}"
    tls_secret       = "${local.ambassador_tls_secret}"
    acme_issuer      = "${local.ambassador_acme_issuer}"
    acme_issuer_kind = "${local.ambassador_acme_issuer_kind}"
    acme_provider    = "${local.ambassador_acme_provider}"
    fqdns            = "${local.ambassador_fqdns_string}"
  }
}

data "helm_repository" "datawire" {
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
}
