#!/usr/bin/env bash
# deploy.sh
# Script para deploy automatizado no ambiente de PRODUCAO do WineFlow
# Uso: ./scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTENV_PATH="$SCRIPT_DIR/../../.env"
TF_DIR="$SCRIPT_DIR/.."

# -- Carregar as variaveis do .env -------
if [[ ! -f "$DOTENV_PATH" ]]; then
    echo "Arquivo .env nao encontrado em: $DOTENV_PATH" >&2
    exit 1
fi

# Exporta credenciais AWS (lidas pelo provider), sem executar o conteudo do .env
# Comparacao case-insensitive: o .env usa chaves minusculas (aws_access_key_id).
while IFS='=' read -r key value; do
    key="${key//[$'\r ']/}"
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="${value%$'\r'}"
    value="${value#[\"\']}"
    value="${value%[\"\']}"
    key_upper="$(echo "$key" | tr '[:lower:]' '[:upper:]')"
    case "$key_upper" in
        AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|AWS_DEFAULT_REGION)
            export "$key_upper=$value" ;;
        KEY_NAME)
            export "TF_VAR_key_name=$value" ;;
        LOCALSTACK_AUTH_TOKEN)
            export "TF_VAR_localstack_auth_token=$value" ;;
    esac
done < "$DOTENV_PATH"

# SCP do Academy nega s3:GetBucketObjectLockConfiguration, quebrando o refresh dos buckets
TF_ARGS=(-refresh=false)

cd "$TF_DIR"

# -- Terraform Init ------------------------------------------------------------
echo -e "\033[36m[DEPLOY - PROD] Inicializando Terraform...\033[0m"
terraform init -reconfigure

# -- Terraform Validate --------------------------------------------------------
echo
echo -e "\033[36m[DEPLOY - PROD] Validando configuracao...\033[0m"
terraform validate
echo -e "\033[32m  Validacao OK!\033[0m"

# -- Terraform Plan ------------------------------------------------------------
echo
echo -e "\033[36m[DEPLOY - PROD] Executando terraform plan...\033[0m"
set +e
terraform plan -detailed-exitcode "${TF_ARGS[@]}"
plan_exit=$?
set -e

if [[ $plan_exit -eq 1 ]]; then
    echo "Erro no terraform plan." >&2
    exit 1
fi

if [[ $plan_exit -eq 0 ]]; then
    echo -e "\033[32m  Nenhuma mudanca detectada. Infra ja esta atualizada.\033[0m"
    exit 0
fi

# -- Terraform Apply -----------------------------------------------------------
echo
echo -e "\033[36m[DEPLOY - PROD] Aplicando infra...\033[0m"
terraform apply -auto-approve "${TF_ARGS[@]}"

# -- Output final --------------------------------------------------------------
echo
echo -e "\033[32m[DEPLOY - PROD] Concluido!\033[0m"
terraform output
