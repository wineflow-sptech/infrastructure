# destroy.ps1
# Script para destruir o ambiente de PRODUCAO do WineFlow
# Uso: .\scripts\destroy.ps1
#
# Os buckets S3 (modulo "s3") sao excluidos de propositado: a SCP do AWS
# Academy nega s3:DeleteBucket (e tambem DeleteBucketEncryption,
# DeletePublicAccessBlock), entao nao ha como apaga-los por aqui. Eles ficam
# ate o lab do Academy expirar/resetar.

$ErrorActionPreference = "Stop"

$OriginalPath = Get-Location
$DotEnvPath = Join-Path $PSScriptRoot "../../.env"

# -- Carregar as variaveis do .env -------
if (-not (Test-Path $DotEnvPath)) {
    throw "Arquivo .env nao encontrado em: $DotEnvPath"
}

$envVars = @{}
Get-Content $DotEnvPath | ForEach-Object {
    if ($_ -match "^([^#\s][^=]*)=(.*)$") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim() -replace '^["'']|["'']$', ''
    }
}

# -- Exportar credenciais AWS para o ambiente (lidas pelo provider) -------
foreach ($name in "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN", "AWS_DEFAULT_REGION") {
    if ($envVars.ContainsKey($name)) {
        Set-Item -Path "Env:$name" -Value $envVars[$name]
    }
}

# -- Terraform Destroy (exclui o modulo s3 - bloqueado pela SCP do Academy) ----
Write-Host "[DESTROY - PROD] Destruindo infra (exceto buckets S3)..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform destroy -auto-approve -refresh=false `
    -target="module.ec2"

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform destroy."
}

Write-Host ""
Write-Host "  Infra destruida (EC2, security group)." -ForegroundColor Green
Write-Host "  Key pair SSH NAO e gerenciado pelo Terraform - apague manualmente se precisar." -ForegroundColor Yellow
Write-Host "  Buckets S3 NAO foram apagados - SCP do Academy nega s3:DeleteBucket." -ForegroundColor Yellow

Set-Location $OriginalPath
