# A SCP do AWS Academy nega tanto a leitura (GetBucketObjectLockConfiguration no
# Read do aws_s3_bucket) quanto a remocao (DeleteBucketEncryption,
# DeletePublicAccessBlock, DeleteBucket) de varias operacoes via provider
# nativo. Por isso bucket, encryption e public-access-block sao geridos via
# AWS CLI (local-exec) em vez dos recursos aws_s3_bucket*.
#
# Como o destroy de bucket e bloqueado pela SCP, os buckets nunca sao
# apagados (ver scripts/destroy.ps1, que exclui o modulo s3 do destroy) -
# por isso, antes de criar um novo, verificamos se ja existe um bucket com
# o prefixo "<bucket_name>-" e reaproveitamos o nome dele em vez de gerar um
# novo sufixo aleatorio.
#
# O null_resource em si NAO tem count condicionado a essa consulta: uma vez
# criado, create-bucket/put-bucket-encryption/put-public-access-block sao
# idempotentes na AWS (re-chamar contra um bucket que voce ja possui so
# confirma o estado, nao erra) - diferente de usar `count` baseado numa
# consulta ao vivo, que oscilaria entre criar/destruir a cada apply (o
# proprio bucket que o Terraform acabou de criar passaria a "existir" na
# consulta seguinte, e o destroy-time provisioner bateria na mesma SCP).
data "external" "existing_bucket" {
  program = ["PowerShell", "-Command", <<-EOT
    $ErrorActionPreference = "Stop"
    $prefix = "${var.bucket_name}-"
    $names = (aws s3api list-buckets --query "Buckets[].Name" --output text) -split "\s+" | Where-Object { $_ -ne "" }
    $match = $names | Where-Object { $_.StartsWith($prefix) } | Select-Object -First 1
    if ($null -eq $match) { $match = "" }
    @{ name = $match } | ConvertTo-Json -Compress
  EOT
  ]
}

resource "random_id" "suffix" {
  byte_length = 4

  keepers = {
    bucket_name = var.bucket_name
  }
}

locals {
  existing_bucket  = data.external.existing_bucket.result.name
  bucket_full_name = local.existing_bucket != "" ? local.existing_bucket : "${var.bucket_name}-${random_id.suffix.hex}"
}

resource "null_resource" "bucket" {
  triggers = {
    bucket_name = local.bucket_full_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"

      aws s3api create-bucket --bucket ${local.bucket_full_name} --region us-east-1
      if ($LASTEXITCODE -ne 0) { exit 1 }

      aws s3api put-bucket-encryption --bucket ${local.bucket_full_name} --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'
      if ($LASTEXITCODE -ne 0) { exit 1 }

      aws s3api put-public-access-block --bucket ${local.bucket_full_name} --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
      if ($LASTEXITCODE -ne 0) { exit 1 }
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    # Nunca deve rodar de fato: a SCP do Academy nega s3:DeleteBucket, e o
    # destroy.ps1 ja exclui este modulo do destroy. Mantido so por seguranca.
    command     = "aws s3api delete-bucket --bucket ${self.triggers.bucket_name} --region us-east-1"
  }
}
