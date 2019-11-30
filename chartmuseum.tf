locals {
  chartmuseum_name            = "chartmuseum"
  chartmuseum_namespace       = local.chartmuseum_name
  chartmuseum_instance        = "${local.chartmuseum_name}-${var.env}"
  chartmuseum_part_of         = var.datacenter
  chartmuseum_managed_by      = "terraform"
  chartmuseum_wait            = false
  chartmuseum_force_update    = false
  chartmuseum_recreate_pods   = false
  chartmuseum_port            = 8080
  chartmuseum_fqdn            = var.chartmuseum_fqdn
  chartmuseum_basic_auth_user = var.chartmuseum_basic_auth_user
  chartmuseum_basic_auth_pass = var.chartmuseum_basic_auth_pass
}

data "template_file" "chartmuseum_values" {
  template = file(
    "${path.module}/templates/${local.chartmuseum_name}-values.yaml.tpl",
  )

  vars = {
    iam_role        = aws_iam_role.chartmuseum.name
    fqdn            = local.chartmuseum_fqdn
    service_name    = local.chartmuseum_name
    service_port    = local.chartmuseum_port
    basic_auth_user = local.chartmuseum_basic_auth_user
    basic_auth_pass = local.chartmuseum_basic_auth_pass
  }
}

resource "kubernetes_namespace" "chartmuseum" {
  metadata {
    name = local.chartmuseum_name

    labels = {
      "app.kubernetes.io/component"  = "chartmuseum"
      "app.kubernetes.io/instance"   = local.chartmuseum_instance
      "app.kubernetes.io/managed-by" = local.chartmuseum_managed_by
      "app.kubernetes.io/name"       = local.chartmuseum_name
      "app.kubernetes.io/part-of"    = local.chartmuseum_part_of
    }

    annotations = {
      "iam.amazonaws.com/permitted" = aws_iam_role.chartmuseum.name
    }
  }
}

resource "helm_release" "chartmuseum" {
  name          = local.chartmuseum_name
  namespace     = local.chartmuseum_namespace
  chart         = "${path.module}/helm/${local.chartmuseum_name}"
  wait          = local.chartmuseum_wait
  force_update  = local.chartmuseum_force_update
  recreate_pods = local.chartmuseum_recreate_pods

  values = [
    data.template_file.chartmuseum_values.rendered,
  ]

  depends_on = [
    kubernetes_namespace.chartmuseum,
    aws_iam_role.chartmuseum,
  ]
}

# IAM roles
data "aws_iam_policy_document" "chartmuseum_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    principals {
      type = "AWS"
      # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
      # force an interpolation expression to be interpreted as a list by wrapping it
      # in an extra set of list brackets. That form was supported for compatibility in
      # v0.11, but is no longer supported in Terraform v0.12.
      #
      # If the expression in the following list itself returns a list, remove the
      # brackets to avoid interpretation as a list of lists. If the expression
      # returns a single list item then leave it as-is and remove this TODO comment.
      identifiers = [local.kiam_assume_role_arn]
    }
  }
}

resource "aws_iam_role" "chartmuseum" {
  name_prefix        = "${local.chartmuseum_name}-"
  description        = "Role to be assumed by ${local.chartmuseum_name} processes"
  assume_role_policy = data.aws_iam_policy_document.chartmuseum_assume_role_policy.json
}

