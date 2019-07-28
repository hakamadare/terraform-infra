# outputs

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "vpc_cidr" {
  value = "${module.vpc.vpc_cidr_block}"
}

output "vpc_azs" {
  value = ["${local.vpc_azs}"]
}

output "vpc_public_cidrs" {
  value = ["${local.vpc_public_cidrs}"]
}

output "vpc_private_cidrs" {
  value = ["${local.vpc_private_cidrs}"]
}

output "vpc_database_cidrs" {
  value = ["${local.vpc_database_cidrs}"]
}

output "tiller_namespace" {
  value = "${local.tiller_namespace}"
}

output "circleci_iam_user_access_key" {
  value = "${module.iam_user_circleci.this_iam_access_key_id}"
}

output "circleci_iam_user_secret_key_decrypt_command" {
  value = "${module.iam_user_circleci.keybase_secret_key_decrypt_command}"
}
