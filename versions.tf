terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "duoc"

  default_tags {
    tags = {
      Project     = var.prefijo
      ManagedBy   = "terraform"
      Provider    = "aws"
      Environment = "lab"
    }
  }
}
