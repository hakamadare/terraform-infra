# ecs clusters

locals {
  ecs_iam_path              = "/ecs/${local.region}/${var.vpc_name}/"
  infra_allowed_cidr_blocks = ["${distinct(compact(flatten(concat(module.vpc.public_subnets_cidr_blocks, module.vpc.private_subnets_cidr_blocks,module.vpc.intra_subnets_cidr_blocks))))}"]
  ecs_infra_name            = "infra-${local.region}-${var.env}"
  ecs_volumes_path          = "/var/lib/docker/volumes"
}

module "infra" {
  source                      = "github.com/terraform-community-modules/tf_aws_ecs?ref=v5.2.0"
  name                        = "${local.ecs_infra_name}"
  key_name                    = "${var.ec2_keypair}"
  vpc_id                      = "${module.vpc.vpc_id}"
  region                      = "${local.region}"
  subnet_id                   = ["${module.vpc.private_subnets}"]
  servers                     = "${var.ecs_servers}"
  min_servers                 = "${var.ecs_min_servers}"
  instance_type               = "${var.ecs_instance_type}"
  iam_path                    = "${local.ecs_iam_path}"
  dockerhub_email             = "${var.ecs_dockerhub_email}"
  dockerhub_token             = "${var.ecs_dockerhub_token}"
  additional_user_data_script = "${data.template_file.infra_user_data.rendered}"

  extra_tags = [
    {
      key                 = "environment"
      value               = "${var.env}"
      propagate_at_launch = true
    },
    {
      key                 = "datacenter"
      value               = "${var.datacenter}"
      propagate_at_launch = true
    },
    {
      key                 = "region"
      value               = "${local.region}"
      propagate_at_launch = true
    },
  ]
}

data "template_file" "infra_user_data" {
  template = "${path.module}/templates/infra_user_data.tmpl"

  vars {
    file_system_id   = "${aws_efs_file_system.ecs_infra_volumes.id}"
    ecs_volumes_path = "${local.ecs_volumes_path}"
  }
}
