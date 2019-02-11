locals {
  ambassador_name           = "ambassador"
  ambassador_repo_url       = "https://www.getambassador.io"
  ambassador_instance       = "${local.ambassador_name}-${var.env}"
  ambassador_version        = "v0.5.2"
  ambassador_part_of        = "${var.datacenter}"
  ambassador_managed_by     = "terraform"
  ambassador_wait           = false
  ambassador_force_update   = false
  ambassador_recreate_pods  = true
  ambassador_namespace      = "${kubernetes_namespace.ambassador.metadata.0.name}"
  ambassador_iam_role       = "${aws_iam_role.ambassador.name}"
  ambassador_acme_email     = "${var.acme_email}"
  ambassador_route53_region = "${data.aws_region.current.name}"
}

data "template_file" "ambassador_values" {
  template = "${file("${path.module}/templates/ambassador-values.yaml.tpl")}"

  vars {
    name       = "${local.ambassador_name}"
    env        = "${var.env}"
    version    = "${local.ambassador_version}"
    iam_role   = "${local.ambassador_iam_role}"
    region     = "${local.ambassador_route53_region}"
    acme_email = "${local.ambassador_acme_email}"
  }
}

resource "kubernetes_namespace" "ambassador" {
  metadata {
    name = "${local.ambassador_name}"

    annotations {
      "iam.amazonaws.com/permitted" = "^${local.ambassador_name}-.*"
    }

    labels {
      "app.kubernetes.io/component"  = "ambassador"
      "app.kubernetes.io/instance"   = "${local.ambassador_instance}"
      "app.kubernetes.io/managed-by" = "${local.ambassador_managed_by}"
      "app.kubernetes.io/name"       = "${local.ambassador_name}"
      "app.kubernetes.io/part-of"    = "${local.ambassador_part_of}"
      "app.kubernetes.io/version"    = "${local.ambassador_version}"
    }
  }
}

resource "helm_repository" "datawire" {
  name = "datawire"
  url  = "${local.ambassador_repo_url}"
}

resource "helm_release" "ambassador" {
  name          = "${local.ambassador_name}"
  namespace     = "${local.ambassador_namespace}"
  chart         = "${path.module}/helm/ambassador"
  wait          = "${local.ambassador_wait}"
  force_update  = "${local.ambassador_force_update}"
  recreate_pods = "${local.ambassador_recreate_pods}"

  values = [
    "${data.template_file.ambassador_values.rendered}",
  ]

  depends_on = [
    "helm_repository.datawire",
    "kubernetes_namespace.ambassador",
  ]
}

# IAM roles
data "aws_iam_policy_document" "ambassador_assume_role_policy" {
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

data "aws_iam_policy_document" "ambassador" {
  statement {
    actions = []

    resources = ["*"]
  }
}

resource "aws_iam_role" "ambassador" {
  name_prefix        = "${local.ambassador_name}-"
  description        = "Role to be assumed by ambassador processes"
  assume_role_policy = "${data.aws_iam_policy_document.ambassador_assume_role_policy.json}"
}

resource "aws_iam_policy" "ambassador" {
  name_prefix = "${local.ambassador_name}-"
  description = "Privileges for ambassador processes"
  policy      = "${data.aws_iam_policy_document.ambassador.json}"
}

resource "aws_iam_role_policy_attachment" "ambassador" {
  role       = "${aws_iam_role.ambassador.name}"
  policy_arn = "${aws_iam_policy.ambassador.arn}"
}
