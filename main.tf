# creating an EIP (elastic IP on AWS)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_eip" "app" {
  domain = "vpc"
  tags = {
    Name = "app-eip"
  }
}

output "eip_public_ip" {
  value = aws_eip.app.public_ip
}