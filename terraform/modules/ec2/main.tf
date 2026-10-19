# Security group e instancia sao recursos normais, sempre geridos pelo
# Terraform (sem count condicional). Adotar um recurso orfao ja existente na
# AWS (achado por nome/tag) e feito via `import` block no root main.tf, nao
# aqui - um `count` baseado numa consulta ao vivo na AWS oscila entre 0 e 1 a
# cada apply (o proprio recurso que o Terraform acabou de criar passa a
# "existir" na consulta seguinte), levando a destruir e nao recriar o
# recurso a cada outra execucao.
locals {
  sg_name           = "wineflow-sg-${var.instance_name}-${var.environment}"
  instance_name_tag = "wineflow-ec2-${var.instance_name}-${var.environment}"
}

resource "aws_security_group" "this" {
  name        = local.sg_name
  description = "Permite trafego de entrada nas portas configuradas"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = local.sg_name
    Environment = var.environment
  }
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  user_data                   = var.user_data != "" ? var.user_data : null
  source_dest_check           = var.source_dest_check
  user_data_replace_on_change = true

  tags = {
    Name        = local.instance_name_tag
    Environment = var.environment
  }
}
