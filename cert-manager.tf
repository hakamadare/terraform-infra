locals {
  cert_manager_name           = "cert-manager"
  cert_manager_instance       = "${local.cert_manager_name}-${var.env}"
  cert_manager_version        = "v0.9.0"
  cert_manager_part_of        = "${var.datacenter}"
  cert_manager_managed_by     = "terraform"
  cert_manager_wait           = false
  cert_manager_force_update   = false
  cert_manager_recreate_pods  = false
  cert_manager_namespace      = "${kubernetes_namespace.cert_manager.metadata.0.name}"
  cert_manager_iam_role       = "${aws_iam_role.cert_manager.name}"
  cert_manager_acme_email     = "${var.acme_email}"
  cert_manager_route53_region = "${data.aws_region.current.name}"
}

data "template_file" "cert_manager_values" {
  template = "${file("${path.module}/templates/cert-manager-values.yaml.tpl")}"

  vars {
    name       = "${local.cert_manager_name}"
    env        = "${var.env}"
    version    = "${local.cert_manager_version}"
    iam_role   = "${local.cert_manager_iam_role}"
    region     = "${local.cert_manager_route53_region}"
    acme_email = "${local.cert_manager_acme_email}"
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "${local.cert_manager_name}"

    annotations {
      "iam.amazonaws.com/permitted" = "^${local.cert_manager_name}-.*"
    }

    labels {
      "app.kubernetes.io/component"           = "cert-manager"
      "app.kubernetes.io/instance"            = "${local.cert_manager_instance}"
      "app.kubernetes.io/managed-by"          = "${local.cert_manager_managed_by}"
      "app.kubernetes.io/name"                = "${local.cert_manager_name}"
      "app.kubernetes.io/part-of"             = "${local.cert_manager_part_of}"
      "app.kubernetes.io/version"             = "${local.cert_manager_version}"
      "certmanager.k8s.io/disable-validation" = "true"
    }
  }
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "cert_manager" {
  name          = "${local.cert_manager_name}"
  namespace     = "${local.cert_manager_namespace}"
  chart         = "${path.module}/helm/cert-manager"
  wait          = "${local.cert_manager_wait}"
  force_update  = "${local.cert_manager_force_update}"
  recreate_pods = "${local.cert_manager_recreate_pods}"

  values = [
    "${data.template_file.cert_manager_values.rendered}",
  ]
}

# IAM roles
data "aws_iam_policy_document" "cert_manager_assume_role_policy" {
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

data "aws_iam_policy_document" "cert_manager" {
  statement {
    actions = [
      "route53:GetChange",
    ]

    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    actions = [
      "route53:ListHostedZonesByName",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "cert_manager" {
  name_prefix        = "cert-manager-"
  description        = "Role to be assumed by cert-manager processes"
  assume_role_policy = "${data.aws_iam_policy_document.cert_manager_assume_role_policy.json}"
}

resource "aws_iam_policy" "cert_manager" {
  name_prefix = "cert-manager-"
  description = "Privileges for cert-manager processes"
  policy      = "${data.aws_iam_policy_document.cert_manager.json}"
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  role       = "${aws_iam_role.cert_manager.name}"
  policy_arn = "${aws_iam_policy.cert_manager.arn}"
}
