locals {
  cluster_id = module.ecs_fargate.ecs_cluster_id
}

module "ecs_fargate" {

  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 3.5"

  name               = "fargate"
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