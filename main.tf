# infrastructure for vecna.org

locals {
  az_count = "${length(data.aws_availability_zones.available.names)}"
  tiers = ["public", "private", "database", "infra"]
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

data "aws_region" "current" {}
