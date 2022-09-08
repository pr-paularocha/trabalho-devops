terraform {
  backend "s3" {
    bucket = "kinesis-paula-0712"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.28.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = "${terraform.workspace}"
    }
  }
}