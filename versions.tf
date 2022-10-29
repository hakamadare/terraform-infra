
terraform {
  required_version = ">= 1.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3, < 5"

    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3"
    }
  }
}
