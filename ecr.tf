# ECR repos
locals {
  ecr_max_image_count           = 50
  ecr_stage                     = "prod"
  iam_pgp_key                   = "keybase:${var.keybase_username}"
  iam_ecr_power_user_policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

data "aws_iam_policy_document" "eks_update_kubeconfig" {
  statement {
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy" "ecr_power_user" {
  arn = local.iam_ecr_power_user_policy_arn
}

resource "aws_iam_policy" "eks_update_kubeconfig" {
  name_prefix = "eks-update-kubeconfig-"
  policy      = data.aws_iam_policy_document.eks_update_kubeconfig.json
}

module "iam_user_circleci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "2.3.0"
  name    = "circleci"
  pgp_key = local.iam_pgp_key
}

resource "aws_iam_user_policy_attachment" "circleci_ecr_power_user" {
  user       = module.iam_user_circleci.this_iam_user_name
  policy_arn = data.aws_iam_policy.ecr_power_user.arn
}

resource "aws_iam_user_policy_attachment" "circleci_eks_update_kubeconfig" {
  user       = module.iam_user_circleci.this_iam_user_name
  policy_arn = aws_iam_policy.eks_update_kubeconfig.arn
}

module "ecr_someguyontheinternet" {
  source                     = "cloudposse/ecr/aws"
  version                    = "0.11.0"
  namespace                  = "static"
  stage                      = local.ecr_stage
  name                       = "someguyontheinternet"
  principals_full_access     = [module.iam_user_circleci.this_iam_user_arn]
  principals_readonly_access = [aws_iam_role.someguyontheinternet.arn]
  max_image_count            = local.ecr_max_image_count
}

module "ecr_deeryam" {
  source                     = "cloudposse/ecr/aws"
  version                    = "0.11.0"
  namespace                  = "static"
  stage                      = local.ecr_stage
  name                       = "deeryam"
  principals_full_access     = [module.iam_user_circleci.this_iam_user_arn]
  principals_readonly_access = [aws_iam_role.deeryam.arn]
  max_image_count            = local.ecr_max_image_count
}

