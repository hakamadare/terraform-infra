locals {
  external_dns_name                    = "external-dns"
  external_dns_namespace               = "${local.external_dns_name}"
  external_dns_instance                = "${local.external_dns_name}-${var.env}"
  external_dns_part_of                 = "${var.datacenter}"
  external_dns_managed_by              = "terraform"
  external_dns_wait                    = false
  external_dns_force_update            = false
  external_dns_recreate_pods           = false
  external_dns_region                  = "${data.aws_region.current.name}"
  external_dns_route53_full_policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

data "template_file" "external_dns_values" {
  template = "${file("${path.module}/templates/${local.external_dns_name}-values.yaml.tpl")}"

  vars {
    region   = "${local.external_dns_region}"
    iam_role = "${aws_iam_role.external_dns.name}"
  }
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "${local.external_dns_name}"

    labels {
      "app.kubernetes.io/component"  = "external_dns"
      "app.kubernetes.io/instance"   = "${local.external_dns_instance}"
      "app.kubernetes.io/managed-by" = "${local.external_dns_managed_by}"
      "app.kubernetes.io/name"       = "${local.external_dns_name}"
      "app.kubernetes.io/part-of"    = "${local.external_dns_part_of}"
    }

    annotations {
      "iam.amazonaws.com/permitted" = "${aws_iam_role.external_dns.name}"
    }
  }
}

resource "helm_release" "external_dns" {
  name          = "${local.external_dns_name}"
  namespace     = "${local.external_dns_namespace}"
  chart         = "${path.module}/helm/${local.external_dns_name}"
  wait          = "${local.external_dns_wait}"
  force_update  = "${local.external_dns_force_update}"
  recreate_pods = "${local.external_dns_recreate_pods}"

  values = [
    "${data.template_file.external_dns_values.rendered}",
  ]

  depends_on = [
    "kubernetes_namespace.external_dns",
    "aws_iam_role.external_dns",
  ]
}

# IAM roles
data "aws_iam_policy" "route53_full" {
  arn = "${local.external_dns_route53_full_policy_arn}"
}

data "aws_iam_policy_document" "external_dns_assume_role_policy" {
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

resource "aws_iam_role" "external_dns" {
  name_prefix        = "${local.external_dns_name}-"
  description        = "Role to be assumed by ${local.external_dns_name} processes"
  assume_role_policy = "${data.aws_iam_policy_document.external_dns_assume_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "external_dns_route53_full" {
  role       = "${aws_iam_role.external_dns.name}"
  policy_arn = "${data.aws_iam_policy.route53_full.arn}"
}
