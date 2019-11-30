# deer-y.am static content
locals {
  deeryam_name              = "deer-yam"
  deeryam_fqdn              = "${data.aws_route53_zone.deer-y_am.name}"
  deeryam_zone_id           = "${data.aws_route53_zone.deer-y_am.zone_id}"
  deeryam_namespace         = "${local.deeryam_name}"
  deeryam_instance          = "${local.deeryam_name}-${var.env}"
  deeryam_part_of           = "${var.datacenter}"
  deeryam_managed_by        = "terraform"
  deeryam_wait              = false
  deeryam_force_update      = false
  deeryam_recreate_pods     = false
  deeryam_registry          = "${module.ecr_deeryam.registry_url}"
  deeryam_image_pull_policy = "Always"
  deeryam_cdn_uuid          = "${var.deeryam_cdn_uuid}"
}

data "template_file" "deeryam_values" {
  template = "${file("${path.module}/templates/${local.deeryam_name}-values.yaml.tpl")}"

  vars {
    name              = "${local.deeryam_name}"
    registry          = "${local.deeryam_registry}"
    image_pull_policy = "${local.deeryam_image_pull_policy}"
    iam_role          = "${aws_iam_role.deeryam.name}"
    cdn_uuid          = "${local.deeryam_cdn_uuid}"
  }
}

resource "kubernetes_namespace" "deeryam" {
  metadata {
    name = "${local.deeryam_name}"

    labels {
      "app.kubernetes.io/component"  = "deeryam"
      "app.kubernetes.io/instance"   = "${local.deeryam_instance}"
      "app.kubernetes.io/managed-by" = "${local.deeryam_managed_by}"
      "app.kubernetes.io/name"       = "${local.deeryam_name}"
      "app.kubernetes.io/part-of"    = "${local.deeryam_part_of}"
    }

    annotations {
      "iam.amazonaws.com/permitted" = "${aws_iam_role.deeryam.name}"
    }
  }
}

resource "helm_release" "deeryam" {
  name          = "${local.deeryam_name}"
  namespace     = "${local.deeryam_namespace}"
  chart         = "${path.module}/helm/static-nginx"
  wait          = "${local.deeryam_wait}"
  force_update  = "${local.deeryam_force_update}"
  recreate_pods = "${local.deeryam_recreate_pods}"

  values = [
    "${data.template_file.deeryam_values.rendered}",
  ]

  depends_on = [
    "kubernetes_namespace.deeryam",
    "aws_iam_role.deeryam",
  ]
}

# IAM roles
data "aws_iam_policy_document" "deeryam_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    principals {
      type        = "AWS"
      identifiers = ["${local.kiam_assume_role_arn}"]
    }
  }
}

resource "aws_iam_role" "deeryam" {
  name_prefix        = "${local.deeryam_name}-"
  description        = "Role to be assumed by ${local.deeryam_name} processes"
  assume_role_policy = "${data.aws_iam_policy_document.deeryam_assume_role_policy.json}"
}
