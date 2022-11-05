
terraform {
  required_version = ">= 1.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4, < 6"

    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13, <2"
    }
  }
}
