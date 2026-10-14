# Antes de criar o security group, verifica se ja existe um com esse nome
# nessa VPC (reaproveita em vez de tentar criar de novo e bater em
# InvalidGroup.Duplicate - pode acontecer se uma apply anterior criou o SG e
# falhou depois, antes de salvar no state).
data "aws_security_groups" "existing" {
  filter {
    name   = "group-name"
    values = [local.sg_name]
  }

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) <= 1
      error_message = "Mais de um security group com o nome ${local.sg_name} (${join(", ", self.ids)}). Remova os duplicados manualmente antes de rodar o deploy de novo."
    }
  }
}

locals {
  sg_name           = "wineflow-sg-${var.instance_name}-${var.environment}"
  existing_sg_id    = length(data.aws_security_groups.existing.ids) > 0 ? data.aws_security_groups.existing.ids[0] : ""
  security_group_id = local.existing_sg_id != "" ? local.existing_sg_id : aws_security_group.this[0].id
}

resource "aws_security_group" "this" {
  count = local.existing_sg_id == "" ? 1 : 0

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

# Antes de criar a instancia, verifica se ja existe uma com essa tag Name
# (pending/running/stopped) e reaproveita, em vez de criar outra a cada
# deploy.
data "aws_instances" "existing" {
  instance_tags = {
    Name = local.instance_name_tag
  }

  instance_state_names = ["pending", "running", "stopping", "stopped"]

  lifecycle {
    postcondition {
      condition     = length(self.ids) <= 1
      error_message = "Mais de uma instancia EC2 com a tag Name=${local.instance_name_tag} (${join(", ", self.ids)}). Termine as duplicadas manualmente antes de rodar o deploy de novo - o Terraform nao sabe qual delas reaproveitar."
    }
  }
}

data "aws_instance" "existing" {
  count       = length(data.aws_instances.existing.ids) > 0 ? 1 : 0
  instance_id = data.aws_instances.existing.ids[0]
}

locals {
  instance_name_tag    = "wineflow-ec2-${var.instance_name}-${var.environment}"
  existing_instance_id = length(data.aws_instances.existing.ids) > 0 ? data.aws_instances.existing.ids[0] : ""
  instance              = local.existing_instance_id != "" ? data.aws_instance.existing[0] : aws_instance.this[0]

  # O atributo da placa de rede primaria tem nome diferente no data source
  # (network_interface_id) e no resource (primary_network_interface_id).
  primary_network_interface_id = local.existing_instance_id != "" ? data.aws_instance.existing[0].network_interface_id : aws_instance.this[0].primary_network_interface_id
}

resource "aws_instance" "this" {
  count = local.existing_instance_id == "" ? 1 : 0

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [local.security_group_id]
  key_name                = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  user_data            = var.user_data != "" ? var.user_data : null
  source_dest_check    = var.source_dest_check
  user_data_replace_on_change = true

  tags = {
    Name        = local.instance_name_tag
    Environment = var.environment
  }
}
