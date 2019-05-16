locals {
  k8s_spot_rescheduler_name          = "k8s-spot-rescheduler"
  k8s_spot_rescheduler_namespace     = "kube-system"
  k8s_spot_rescheduler_instance      = "${local.k8s_spot_rescheduler_name}-${var.env}"
  k8s_spot_rescheduler_version       = "v0.2.0"
  k8s_spot_rescheduler_part_of       = "${var.datacenter}"
  k8s_spot_rescheduler_managed_by    = "terraform"
  k8s_spot_rescheduler_wait          = false
  k8s_spot_rescheduler_force_update  = false
  k8s_spot_rescheduler_recreate_pods = false
}

data "template_file" "k8s_spot_rescheduler_values" {
  template = "${file("${path.module}/templates/k8s-spot-rescheduler-values.yaml.tpl")}"

  vars {
    version = "${local.k8s_spot_rescheduler_version}"
  }
}

resource "helm_release" "k8s_spot_rescheduler" {
  name          = "${local.k8s_spot_rescheduler_name}"
  namespace     = "${local.k8s_spot_rescheduler_namespace}"
  chart         = "${path.module}/helm/k8s-spot-rescheduler"
  wait          = "${local.k8s_spot_rescheduler_wait}"
  force_update  = "${local.k8s_spot_rescheduler_force_update}"
  recreate_pods = "${local.k8s_spot_rescheduler_recreate_pods}"

  values = [
    "${data.template_file.k8s_spot_rescheduler_values.rendered}",
  ]
}
