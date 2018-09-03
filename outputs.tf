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

output "infra_allowed_cidr_blocks" {
  value = ["${local.infra_allowed_cidr_blocks}"]
}
