variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID para EC2 Ubuntu"
  type        = string
  # Ubuntu 22.04 LTS em us-east-1 (Mude dependendo da necessidade ou use data source)
  default = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  description = "Tipo de Instância"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet onde a EC2 será alocada"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "instance_name" {
  description = "Nome da Instância"
  type        = string
}

variable "key_name" {
  description = "Nome do par de chaves SSH (Opcional, mas recomendado)"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "Script de inicializacao (User Data)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "Lista de CIDRs permitidos para as portas de entrada"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile para acesso S3"
  type        = string
  default     = ""
}

variable "source_dest_check" {
  description = "Define controle de roteamento da rede na placa (desligar para NAT)"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Tamanho do disco raiz (GB)"
  type        = number
  default     = 30
}

variable "ingress_ports" {
  description = "Portas TCP liberadas na entrada"
  type        = list(number)
  default     = [22]
}
