# BACKEND
terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "yros"
    workspaces {
      prefix = "yros-aws-core-platform-"
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
