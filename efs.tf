# elastic file system resources

locals {
  ecs_infra_volumes_name = "${local.ecs_infra_name}-volumes"
}

resource "aws_efs_file_system" "ecs_infra_volumes" {
  creation_token   = "${local.ecs_infra_volumes_name}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    "Name"        = "${local.ecs_infra_volumes_name}"
    "environment" = "${var.env}"
    "datacenter"  = "${var.datacenter}"
    "region"      = "${local.region}"
  }
}

resource "aws_efs_mount_target" "ecs_infra_volumes" {
  count          = "${local.az_count}"
  file_system_id = "${aws_efs_file_system.ecs_infra_volumes.id}"
  subnet_id      = "${module.vpc.intra_subnets[count.index]}"

  security_groups = [
    "${data.aws_security_group.ecs.id}",
  ]
}
