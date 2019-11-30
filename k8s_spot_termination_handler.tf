locals {
  k8s_spot_termination_handler_name          = "k8s-spot-termination-handler"
  k8s_spot_termination_handler_namespace     = "kube-system"
  k8s_spot_termination_handler_instance      = "${local.k8s_spot_termination_handler_name}-${var.env}"
  k8s_spot_termination_handler_version       = "1.12.0-2"
  k8s_spot_termination_handler_part_of       = var.datacenter
  k8s_spot_termination_handler_managed_by    = "terraform"
  k8s_spot_termination_handler_wait          = false
  k8s_spot_termination_handler_force_update  = false
  k8s_spot_termination_handler_recreate_pods = false
  k8s_spot_termination_handler_detach_asg    = true
}

data "template_file" "k8s_spot_termination_handler_values" {
  template = file(
    "${path.module}/templates/k8s-spot-termination-handler-values.yaml.tpl",
  )

  vars = {
    version    = local.k8s_spot_termination_handler_version
    detach_asg = local.k8s_spot_termination_handler_detach_asg
  }
}

resource "helm_release" "k8s_spot_termination_handler" {
  name          = local.k8s_spot_termination_handler_name
  namespace     = local.k8s_spot_termination_handler_namespace
  chart         = "${path.module}/helm/k8s-spot-termination-handler"
  wait          = local.k8s_spot_termination_handler_wait
  force_update  = local.k8s_spot_termination_handler_force_update
  recreate_pods = local.k8s_spot_termination_handler_recreate_pods

  values = [
    data.template_file.k8s_spot_termination_handler_values.rendered,
  ]
}

