terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "heungbot-terraform-state-bucket"
    key    = "state/terraform_state.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = var.AWS_REGION
  alias  = "korea"
}
