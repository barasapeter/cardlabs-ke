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
  region = var.region
}

data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_iam_policy" "ssm_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.instance_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.instance_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

locals {
  subnet_id = data.aws_subnets.default.ids[0]

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Drop bootstrap script onto instance
    cat > /home/ubuntu/bootstrap.sh <<'SCRIPT'
    ${file("${path.module}/bootstrap.sh")}
    SCRIPT

    chmod +x /home/ubuntu/bootstrap.sh
    chown ubuntu:ubuntu /home/ubuntu/bootstrap.sh

    # Run bootstrap (your script requires POSTGRES_PASSWORD)
    export POSTGRES_PASSWORD='${var.postgres_password}'
    sudo -E /home/ubuntu/bootstrap.sh

    echo "bootstrap completed" > /home/ubuntu/BOOTSTRAP_DONE
  EOF
}

resource "aws_security_group" "portfolio_sg" {
  name        = "${var.instance_name}-sg"
  description = "portfolio-blog-machine SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere (as requested)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# --- ec2 instance (with No key pair) ---
resource "aws_instance" "portfolio" {
  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.micro"
  subnet_id     = local.subnet_id

  vpc_security_group_ids = [aws_security_group.portfolio_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = local.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    iops        = 3000
    encrypted   = false
  }

  tags = {
    Name = var.instance_name
  }
}

data "aws_eip" "existing" {
  count     = var.attach_eip ? 1 : 0
  public_ip = var.eip_public_ip
}

resource "aws_eip_association" "attach" {
  count         = var.attach_eip ? 1 : 0
  instance_id   = aws_instance.portfolio.id
  allocation_id = data.aws_eip.existing[0].id
}
