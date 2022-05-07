locals {
  iam_pgp_key = "keybase:${var.keybase_username}"
}
module "iam_user_circleci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "4.24.0"
  name    = "circleci"
  pgp_key = local.iam_pgp_key
}
