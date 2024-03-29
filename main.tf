# infrastructure for vecna.org

locals {
  az_count = length(local.vpc_azs)
  tiers    = ["public", "private", "database", "infra"]
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
}

data "aws_region" "current" {
}

data "aws_api_gateway_rest_api" "api" {
  name = var.rest_api_root
}

