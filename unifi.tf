locals {
  unifi_name            = "unifi"
  unifi_namespace       = local.unifi_name
  unifi_instance        = "${local.unifi_name}-${var.env}"
  unifi_part_of         = var.datacenter
  unifi_managed_by      = "terraform"
  unifi_wait            = false
  unifi_force_update    = false
  unifi_recreate_pods   = false
}

resource "kubernetes_namespace" "unifi" {
  metadata {
    name = local.unifi_name

    labels = {
      "app.kubernetes.io/component"  = "unifi"
      "app.kubernetes.io/instance"   = local.unifi_instance
      "app.kubernetes.io/managed-by" = local.unifi_managed_by
      "app.kubernetes.io/name"       = local.unifi_name
      "app.kubernetes.io/part-of"    = local.unifi_part_of
    }

    annotations = {
      "iam.amazonaws.com/permitted" = aws_iam_role.unifi.name
    }
  }
}

# IAM roles
data "aws_iam_policy_document" "unifi_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    principals {
      type = "AWS"
      identifiers = [local.kiam_assume_role_arn]
    }
  }
}

resource "aws_iam_role" "unifi" {
  name_prefix        = "${local.unifi_name}-"
  description        = "Role to be assumed by ${local.unifi_name} processes"
  assume_role_policy = data.aws_iam_policy_document.unifi_assume_role_policy.json
}

