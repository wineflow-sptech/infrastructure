# deploy.ps1
# Script para deploy automatizado no ambiente de PRODUCAO do WineFlow
# Uso: .\scripts\deploy.ps1

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

# -- Key pair SSH (cada dev cria o seu na AWS e informa o nome no .env) -------
# KEY_NAME=nome-do-seu-key-pair no .env -> instancia sobe associada a ele.
# Sem KEY_NAME, a instancia sobe sem key pair (sem acesso SSH).
if ($envVars.ContainsKey("KEY_NAME")) {
    Set-Item -Path "Env:TF_VAR_key_name" -Value $envVars["KEY_NAME"]
}

$varArgs = @("-refresh=false") # SCP do Academy nega s3:GetBucketObjectLockConfiguration, quebrando o refresh dos buckets

# -- Terraform Init ------------------------------------------------------------
Write-Host "[DEPLOY - PROD] Inicializando Terraform..." -ForegroundColor Cyan
Set-Location (Join-Path $PSScriptRoot "..")

terraform init -reconfigure
if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform init."
}

# -- Terraform Validate --------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Validando configuracao..." -ForegroundColor Cyan
terraform validate
if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform validate."
}
Write-Host "  Validacao OK!" -ForegroundColor Green

# -- Terraform Plan ------------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Executando terraform plan..." -ForegroundColor Cyan
terraform plan -detailed-exitcode @varArgs
$planExit = $LASTEXITCODE

if ($planExit -eq 1) {
    Set-Location $OriginalPath
    throw "Erro no terraform plan."
}

if ($planExit -eq 0) {
    Write-Host "  Nenhuma mudanca detectada. Infra ja esta atualizada." -ForegroundColor Green
    Set-Location $OriginalPath
    exit 0
}

# -- Terraform Apply -----------------------------------------------------------
Write-Host ""
Write-Host "[DEPLOY - PROD] Aplicando infra..." -ForegroundColor Cyan
terraform apply -auto-approve @varArgs

if ($LASTEXITCODE -ne 0) {
    Set-Location $OriginalPath
    throw "Erro no terraform apply."
}

# -- Output final --------------------------------------------------------------
function Get-TFOutput($name) {
    $val = terraform output -raw $name 2>$null
    if ($val) { return $val } else { return "(unavailable)" }
}