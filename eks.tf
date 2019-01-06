locals {
  eks_cluster_name       = "prod"
  eks_subnets            = "${module.vpc.private_subnets}"
  eks_vpc                = "${module.vpc.vpc_id}"
  eks_config_output_path = "${pathexpand("~/.kube")}/"
  eks_aws_profile        = "${var.vpc_name}"
  eks_admin_username     = "${var.eks_admin_username}"
  eks_map_users_count    = "${length(local.eks_map_users)}"
  eks_instance_type      = "t3.small"
  eks_cluster_size       = "3"
  eks_cluster_min        = "2"
  eks_cluster_max        = "${local.eks_cluster_size + 1}"
  eks_version            = "1.11"

  eks_map_users = [
    {
      user_arn = "${data.aws_iam_user.eks_admin.arn}"
      username = "${local.eks_admin_username}"
      group    = "system:masters"
    },
  ]

  eks_worker_groups = [
    {
      instance_type        = "${local.eks_instance_type}"
      asg_desired_capacity = "${local.eks_cluster_size}"
      asg_min_size         = "${local.eks_cluster_min}"
      asg_max_size         = "${local.eks_cluster_max}"
    },
  ]
}

variable "eks_admin_username" {
  type        = "string"
  description = "IAM username to map to EKS admin"
  default     = ""
}

data "aws_iam_user" "eks_admin" {
  user_name = "${var.eks_admin_username}"
}

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "1.7.0"
  cluster_name                   = "${local.eks_cluster_name}"
  cluster_version                = "${local.eks_version}"
  subnets                        = "${local.eks_subnets}"
  vpc_id                         = "${local.eks_vpc}"
  config_output_path             = "${local.eks_config_output_path}"
  create_elb_service_linked_role = false
  map_users                      = "${local.eks_map_users}"
  worker_groups                  = "${local.eks_worker_groups}"

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = "${local.eks_aws_profile}"
  }

  tags = {
    environment = "production"
    datacenter  = "${var.datacenter}"
    region      = "${data.aws_region.current.name}"
  }
}
