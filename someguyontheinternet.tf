# someguyontheinter.net static content
locals {
  someguyontheinternet_name              = "someguyontheinternet"
  someguyontheinternet_namespace         = "${local.someguyontheinternet_name}"
  someguyontheinternet_instance          = "${local.someguyontheinternet_name}-${var.env}"
  someguyontheinternet_part_of           = "${var.datacenter}"
  someguyontheinternet_managed_by        = "terraform"
  someguyontheinternet_wait              = false
  someguyontheinternet_force_update      = false
  someguyontheinternet_recreate_pods     = false
  someguyontheinternet_registry          = "${module.ecr_someguyontheinternet.registry_url}"
  someguyontheinternet_image_pull_policy = "Always"
  someguyontheinternet_cdn_uuid          = "${var.someguyontheinternet_cdn_uuid}"
}

data "template_file" "someguyontheinternet_values" {
  template = "${file("${path.module}/templates/${local.someguyontheinternet_name}-values.yaml.tpl")}"

  vars {
    name              = "${local.someguyontheinternet_name}"
    registry          = "${local.someguyontheinternet_registry}"
    image_pull_policy = "${local.someguyontheinternet_image_pull_policy}"
    iam_role          = "${aws_iam_role.someguyontheinternet.name}"
    cdn_uuid          = "${local.someguyontheinternet_cdn_uuid}"
  }
}

resource "kubernetes_namespace" "someguyontheinternet" {
  metadata {
    name = "${local.someguyontheinternet_name}"

    labels {
      "app.kubernetes.io/component"  = "someguyontheinternet"
      "app.kubernetes.io/instance"   = "${local.someguyontheinternet_instance}"
      "app.kubernetes.io/managed-by" = "${local.someguyontheinternet_managed_by}"
      "app.kubernetes.io/name"       = "${local.someguyontheinternet_name}"
      "app.kubernetes.io/part-of"    = "${local.someguyontheinternet_part_of}"
    }

    annotations {
      "iam.amazonaws.com/permitted" = "${aws_iam_role.someguyontheinternet.name}"
    }
  }
}

resource "helm_release" "someguyontheinternet" {
  name          = "${local.someguyontheinternet_name}"
  namespace     = "${local.someguyontheinternet_namespace}"
  chart         = "${path.module}/helm/static-nginx"
  wait          = "${local.someguyontheinternet_wait}"
  force_update  = "${local.someguyontheinternet_force_update}"
  recreate_pods = "${local.someguyontheinternet_recreate_pods}"

  values = [
    "${data.template_file.someguyontheinternet_values.rendered}",
  ]

  depends_on = [
    "kubernetes_namespace.someguyontheinternet",
    "aws_iam_role.someguyontheinternet",
  ]
}

# IAM roles
data "aws_iam_policy_document" "someguyontheinternet_assume_role_policy" {
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

resource "aws_iam_role" "someguyontheinternet" {
  name_prefix        = "${local.someguyontheinternet_name}-"
  description        = "Role to be assumed by ${local.someguyontheinternet_name} processes"
  assume_role_policy = "${data.aws_iam_policy_document.someguyontheinternet_assume_role_policy.json}"
}
