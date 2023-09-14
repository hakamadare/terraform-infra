# vpc

locals {
  region    = data.aws_region.current.name
  limit_azs = length(local.vpc_public_cidrs)
  vpc_name  = "${var.vpc_name}-${local.region}"
  vpc_id    = module.vpc.vpc_id
  vpc_azs = slice(
    data.aws_availability_zones.available.names,
    0,
    local.limit_azs,
  )

  vpc_all_cidrs = sort(distinct(compact(concat(local.vpc_public_cidrs, local.vpc_private_cidrs, local.vpc_database_cidrs, local.vpc_intra_cidrs, local.vpc_elasticache_cidrs))))

  vpc_dns_cidrs = [
    cidrsubnet(var.vpc_cidr, 16, 2)
  ]

  vpc_public_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
  ]

  vpc_public_subnet_tags = {
    "tier" = "public"
  }

  vpc_private_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 10),
    cidrsubnet(var.vpc_cidr, 8, 20),
  ]

  vpc_private_subnet_tags = {
    "tier" = "private"
  }

  vpc_database_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 101),
    cidrsubnet(var.vpc_cidr, 8, 102),
  ]

  vpc_database_subnet_tags = {
    "tier" = "database"
  }

  vpc_intra_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 111),
    cidrsubnet(var.vpc_cidr, 8, 112),
  ]

  vpc_intra_subnet_tags = {
    "tier" = "intra"
  }

  vpc_elasticache_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 121),
    cidrsubnet(var.vpc_cidr, 8, 122),
  ]

  vpc_elasticache_subnet_tags = {
    "tier" = "elasticache"
  }

  tags_all = {
    environment = "production"
    datacenter  = var.datacenter
    region      = data.aws_region.current.name
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.14"

  create_vpc = true

  name = local.vpc_name
  cidr = var.vpc_cidr
  azs  = local.vpc_azs

  enable_dns_support      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = false

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  public_subnets      = local.vpc_public_cidrs
  private_subnets     = local.vpc_private_cidrs
  database_subnets    = local.vpc_database_cidrs
  intra_subnets       = local.vpc_intra_cidrs
  elasticache_subnets = local.vpc_elasticache_cidrs

  public_subnet_tags      = local.vpc_public_subnet_tags
  private_subnet_tags     = local.vpc_private_subnet_tags
  database_subnet_tags    = local.vpc_database_subnet_tags
  intra_subnet_tags       = local.vpc_intra_subnet_tags
  elasticache_subnet_tags = local.vpc_elasticache_subnet_tags

  public_route_table_tags = {
    "tier" = "public"
  }

  private_route_table_tags = {
    "tier" = "private"
  }

  intra_route_table_tags = {
    "tier" = "intra"
  }

  create_database_subnet_group    = true
  create_elasticache_subnet_group = true

  tags = local.tags_all
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.14"

  vpc_id = local.vpc_id
  tags   = local.tags_all

  endpoints = {
    s3 = {
      service            = "s3"
      security_group_ids = [aws_security_group.s3_endpoint.id]
    }
    # dynamodb = {
    # service = "dynamodb"
    # }
  }

}

resource "aws_security_group" "s3_endpoint" {
  name_prefix = "s3-endpoint-"
  description = "Permit access to S3 endpoint"
  vpc_id      = local.vpc_id
}

resource "aws_security_group_rule" "s3_endpoint_ingress" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_blocks       = local.vpc_all_cidrs
  security_group_id = aws_security_group.s3_endpoint.id
}

resource "aws_security_group_rule" "s3_endpoint_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.s3_endpoint.id
  cidr_blocks       = ["0.0.0.0/0"]
}
