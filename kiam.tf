locals {
  kiam_name          = "kiam"
  kiam_instance      = "${local.kiam_name}-${var.env}"
  kiam_version       = "v3.3"
  kiam_part_of       = var.datacenter
  kiam_managed_by    = "Tiller"
  kiam_wait          = false
  kiam_force_update  = false
  kiam_recreate_pods = true
  kiam_namespace     = local.kiam_name

  kiam_agent_secret  = "${local.kiam_name}-agent-tls"
  kiam_server_secret = "${local.kiam_name}-server-tls"

  kiam_assume_role_arn = aws_iam_role.kiam_server_process.arn
}

data "template_file" "kiam_values" {
  template = file("${path.module}/templates/kiam-values.yaml.tpl")

  vars = {
    name            = local.kiam_name
    env             = var.env
    version         = local.kiam_version
    namespace       = local.kiam_namespace
    agent_secret    = local.kiam_agent_secret
    server_secret   = local.kiam_server_secret
    assume_role_arn = local.kiam_assume_role_arn
  }
}

resource "kubernetes_namespace" "kiam" {
  metadata {
    name = local.kiam_name

    labels = {
      "app.kubernetes.io/component"  = "kiam"
      "app.kubernetes.io/instance"   = local.kiam_instance
      "app.kubernetes.io/managed-by" = local.kiam_managed_by
      "app.kubernetes.io/name"       = local.kiam_name
      "app.kubernetes.io/part-of"    = local.kiam_part_of
      "app.kubernetes.io/version"    = local.kiam_version
    }
  }
}

resource "helm_release" "kiam" {
  name          = local.kiam_name
  namespace     = local.kiam_namespace
  chart         = "${path.module}/helm/kiam"
  wait          = local.kiam_wait
  force_update  = local.kiam_force_update
  recreate_pods = local.kiam_recreate_pods

  values = [
    data.template_file.kiam_values.rendered,
  ]
}

# IAM resources
locals {
  kiam_server_instance_role_name = module.eks.worker_iam_role_name
  kiam_server_instance_role_arn  = module.eks.worker_iam_role_arn
}

data "aws_iam_policy_document" "kiam_server_instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kiam_server_instance_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    resources = [aws_iam_role.kiam_server_process.arn]
  }
}

data "aws_iam_policy_document" "kiam_server_process_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

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
      identifiers = [local.kiam_server_instance_role_arn]
    }
  }
}

data "aws_iam_policy_document" "kiam_server_process_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "kiam_server_instance" {
  name_prefix = "kiam-server-"
  description = "Policy for the Kiam Server instance"

  policy = data.aws_iam_policy_document.kiam_server_instance_policy.json
}

resource "aws_iam_role_policy_attachment" "kiam_server_instance" {
  role       = local.kiam_server_instance_role_name
  policy_arn = aws_iam_policy.kiam_server_instance.arn
}

resource "aws_iam_role" "kiam_server_process" {
  name_prefix        = "kiam-server-"
  description        = "Role the Kiam Server process assumes"
  assume_role_policy = data.aws_iam_policy_document.kiam_server_process_assume_role_policy.json
}

resource "aws_iam_policy" "kiam_server_process" {
  name_prefix = "kiam-server-"
  description = "Policy for the Kiam Server process"

  policy = data.aws_iam_policy_document.kiam_server_process_policy.json
}

resource "aws_iam_role_policy_attachment" "kiam_server_process" {
  role       = aws_iam_role.kiam_server_process.name
  policy_arn = aws_iam_policy.kiam_server_process.arn
}

