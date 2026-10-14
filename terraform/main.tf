terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  environment = "prod"
  buckets     = toset(["bronze", "silver", "gold"])
}

# -- VPC padrao ----------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -- AMI Ubuntu Server 22.04 ---------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# -- Key pair SSH (criado manualmente por cada usuario na AWS; informe o nome) --
variable "key_name" {
  description = "Nome do key pair SSH ja existente na AWS (criado manualmente por cada usuario). Deixe vazio para subir sem acesso SSH."
  type        = string
  default     = ""
}

# -- EC2 -----------------------------------------------------------------------
module "ec2" {
  source = "./modules/ec2"

  environment          = local.environment
  instance_name        = "kali"
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = "t3.medium"
  root_volume_size     = 30
  vpc_id               = data.aws_vpc.default.id
  subnet_id            = sort(data.aws_subnets.default.ids)[0]
  key_name             = var.key_name
  ingress_ports        = [22, 6901]
  iam_instance_profile = "LabInstanceProfile"
}

# -- Buckets S3 (sufixo aleatorio gerado pela AWS via bucket_prefix) -------------
module "s3" {
  for_each = local.buckets
  source   = "./modules/s3"

  environment = local.environment
  bucket_name = "wineflow-${each.key}"
}

output "kali_public_ip" {
  value = module.ec2.public_ip
}

output "bucket_names" {
  value = { for k, m in module.s3 : k => m.bucket_id }
}
