locals {
  eks_cluster_name                = "prod"
  eks_subnets                     = module.vpc.private_subnets
  eks_vpc                         = module.vpc.vpc_id
  eks_config_output_path          = "${pathexpand("~/.kube")}/"
  eks_aws_profile                 = var.vpc_name
  eks_admin_username              = var.eks_admin_username
  eks_manage_aws_auth             = "true"
  eks_map_users_count             = "2"
  eks_ondemand_instance_type      = "t3.small"
  eks_ondemand_cluster_min        = "1"
  eks_ondemand_cluster_max        = local.eks_ondemand_cluster_min + 1
  eks_ondemand_kubelet_extra_args = "--node-labels=kubernetes.io/lifecycle=normal,node-role.kubernetes.io/worker=true --register-with-taints=node-role.kubernetes.io/worker=true:PreferNoSchedule"
  eks_spot_instance_type          = "t3.medium"
  eks_spot_cluster_min            = "2"
  eks_spot_cluster_max            = local.eks_spot_cluster_min + 2
  eks_spot_kubelet_extra_args     = "--node-labels=kubernetes.io/lifecycle=spot,node-role.kubernetes.io/spot-worker=true"
  eks_spot_price                  = "0.0416"
  eks_suspended_processes         = "AZRebalance"
  eks_version                     = "1.13"

  eks_map_users = [
    {
      user_arn = data.aws_iam_user.eks_admin.arn
      username = local.eks_admin_username
      group    = "system:masters"
    },
    {
      user_arn = module.iam_user_circleci.this_iam_user_arn
      username = module.iam_user_circleci.this_iam_user_name
      group    = "system:masters"
    },
  ]

  eks_worker_groups = [
    {
      name                  = "ondemand"
      instance_type         = local.eks_ondemand_instance_type
      asg_min_size          = local.eks_ondemand_cluster_min
      asg_max_size          = local.eks_ondemand_cluster_max
      kubelet_extra_args    = local.eks_ondemand_kubelet_extra_args
      suspended_processes   = local.eks_suspended_processes
      autoscaling_enabled   = true
      protect_from_scale_in = true
    },
    {
      name                  = "spot"
      spot_price            = local.eks_spot_price
      instance_type         = local.eks_spot_instance_type
      asg_min_size          = local.eks_spot_cluster_min
      asg_max_size          = local.eks_spot_cluster_max
      kubelet_extra_args    = local.eks_spot_kubelet_extra_args
      suspended_processes   = local.eks_suspended_processes
      autoscaling_enabled   = true
      protect_from_scale_in = true
    },
  ]

  eks_worker_group_count = length(local.eks_worker_groups)
}

variable "eks_admin_username" {
  type        = string
  description = "IAM username to map to EKS admin"
  default     = ""
}

data "aws_iam_user" "eks_admin" {
  user_name = var.eks_admin_username
}

module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "4.0.2"
  cluster_name       = local.eks_cluster_name
  cluster_version    = local.eks_version
  subnets            = local.eks_subnets
  vpc_id             = local.eks_vpc
  config_output_path = local.eks_config_output_path
  manage_aws_auth    = local.eks_manage_aws_auth
  map_users          = local.eks_map_users
  worker_groups      = local.eks_worker_groups
  worker_group_count = local.eks_worker_group_count

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = local.eks_aws_profile
  }

  tags = {
    environment = "production"
    datacenter  = var.datacenter
    region      = data.aws_region.current.name
  }
}

