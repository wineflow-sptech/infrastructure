output "instance_id" {
  description = "ID da instância EC2 (criada agora ou reaproveitada se ja existia)"
  value       = local.instance.id
}

output "public_ip" {
  description = "IP Público da instância EC2"
  value       = local.instance.public_ip
}

output "private_ip" {
  description = "IP Privado da instância EC2"
  value       = local.instance.private_ip
}

output "primary_network_interface_id" {
  description = "ID da placa de rede (Usado para tráfego NAT)"
  value       = local.primary_network_interface_id
}

output "security_group_id" {
  description = "ID do Security Group (criado agora ou reaproveitado se ja existia)"
  value       = local.security_group_id
}
