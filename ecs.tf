locals {
  fargate_cluster_id = module.ecs_fargate.ecs_cluster_id
  ec2_cluster_id     = module.ecs_ec2.cluster_name

  ec2_identifier = "ec2"

  fargate_identifier = "fargate"

  putin_khuylo = true
}

module "ecs_fargate" {

  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 3.5"

  name               = local.fargate_identifier
  container_insights = true

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
  ]

  default_capacity_provider_strategy = [
    {
      base              = 0
      capacity_provider = "FARGATE"
      weight            = 1
    }
  ]

  tags = local.tags_all
}

data "aws_autoscaling_group" "ec2_ecs_spot" {
  name = "ec2-ecs-spot"
}

data "aws_launch_template" "ec2_ecs_spot" {
  name = "ec2-ecs-spot"
}

data "aws_iam_role" "ec2_ecs" {
  name = "ec2-ecs"
}

data "aws_security_group" "ec2_ecs" {
  name   = "ec2-ecs"
  vpc_id = local.vpc_id
}

resource "aws_iam_instance_profile" "ec2_ecs" {
  name_prefix = "prod"
  role        = data.aws_iam_role.ec2_ecs.name
}

module "ecs_ec2" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4"

  cluster_name = local.ec2_identifier

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"

      log_configuration = {
        cloud_watch_log_group_name = "ecs/${local.ec2_identifier}"
      }
    }
  }

  default_capacity_provider_use_fargate = false

  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  autoscaling_capacity_providers = {
    spot = {
      auto_scaling_group_arn         = data.aws_autoscaling_group.ec2_ecs_spot.arn
      managed_termination_protection = "DISABLED"

      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "DISABLED"
        target_capacity           = 1
      }

      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  tags = local.tags_all
}
