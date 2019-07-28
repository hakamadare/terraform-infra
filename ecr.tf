# ECR repos
locals {
  ecr_max_image_count           = 50
  ecr_stage                     = "prod"
  iam_pgp_key                   = "keybase:${var.keybase_username}"
  iam_ecr_power_user_policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

data "aws_iam_policy" "ecr_power_user" {
  arn = "${local.iam_ecr_power_user_policy_arn}"
}

module "iam_user_circleci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "1.0.0"
  name    = "circleci"
  pgp_key = "${local.iam_pgp_key}"
}

resource "aws_iam_user_policy_attachment" "circleci_ecr_power_user" {
  user       = "${module.iam_user_circleci.this_iam_user_name}"
  policy_arn = "${data.aws_iam_policy.ecr_power_user.arn}"
}

module "ecr_someguyontheinternet" {
  source                     = "cloudposse/ecr/aws"
  version                    = "0.6.1"
  namespace                  = "static"
  stage                      = "${local.ecr_stage}"
  name                       = "someguyontheinternet"
  principals_full_access     = ["${module.iam_user_circleci.this_iam_user_arn}"]
  principals_readonly_access = ["${aws_iam_role.someguyontheinternet.arn}"]
  max_image_count            = "${local.ecr_max_image_count}"
}
