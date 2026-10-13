# infrastructure

Infraestrutura como código (Terraform) do WineFlow na AWS.

## O que é provisionado

| Recurso | Detalhes |
|---|---|
| EC2 `kali` | Ubuntu Server 22.04, `t3.medium`, SSD 30 GB (gp3), `LabInstanceProfile` |
| Security Group | Entrada TCP nas portas 22 (SSH) e 6901 |
| Chave SSH | Gerada pelo Terraform e salva em `terraform/kali-key.pem` |
| S3 | 3 buckets: `wineflow-bronze-`, `wineflow-silver-` e `wineflow-gold-` + sufixo aleatório da AWS |

Região: `us-east-1`. A rede usa a **VPC padrão** da conta. O módulo `terraform/modules/vpc` existe, mas não é usado no `main.tf`.

## Estrutura

```
infrastructure/
├── .env.example            # modelo das credenciais
├── .env                    # credenciais reais (ignorado pelo git)
└── terraform/
    ├── main.tf             # módulo raiz
    ├── modules/
    │   ├── ec2/
    │   ├── s3/
    │   └── vpc/
    └── scripts/
        ├── deploy.ps1      # deploy no Windows
        └── deploy.sh       # deploy no Linux
```

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- Credenciais AWS (no AWS Academy: *AWS Details* > *AWS CLI*)

## Configuração

1. Copie o modelo e preencha com as credenciais da AWS:

   ```bash
   cp .env.example .env
   ```

   ```env
   AWS_ACCESS_KEY_ID=
   AWS_SECRET_ACCESS_KEY=
   AWS_SESSION_TOKEN=
   ```

2. No AWS Academy o token expira junto com a sessão do lab. Quando aparecer `ExpiredToken`, atualize o `.env`.

## Como rodar

### Pelo script (recomendado)

Os scripts carregam o `.env`, rodam `init`, `validate` e `plan`, e aplicam só se houver mudanças. Funcionam de qualquer diretório.

**Windows (PowerShell):**

```powershell
.\terraform\scripts\deploy.ps1
```

**Linux:**

```bash
./terraform/scripts/deploy.sh
```

No final, o `deploy.sh` mostra o IP público da EC2 e os nomes dos buckets.

### Manualmente

Carregue as credenciais no ambiente e rode a partir de `terraform/`.

**Linux / macOS:**

```bash
cd terraform
set -a; source ../.env; set +a
terraform init
terraform plan -refresh=false
terraform apply -refresh=false
```

**Windows (PowerShell):**

```powershell
cd terraform
Get-Content ..\.env | ForEach-Object { if ($_ -match '^([^#\s][^=]*)=(.*)$') { Set-Item -Path "Env:$($matches[1].Trim())" -Value $matches[2].Trim() } }
terraform init
terraform plan -refresh=false
terraform apply -refresh=false
```

> **Por que `-refresh=false`?** No AWS Academy, uma SCP da organização nega `s3:GetBucketObjectLockConfiguration`. O provider AWS faz essa leitura ao atualizar os buckets, e o `plan`, o `apply` e o `destroy` falham com **403 AccessDenied**. Os scripts já incluem a flag. A consequência é que o Terraform não detecta alterações feitas fora dele, como mudanças manuais no console.

## Acessar a EC2

```bash
chmod 600 terraform/kali-key.pem
ssh -i terraform/kali-key.pem ubuntu@<kali_public_ip>
```

O IP aparece no output `kali_public_ip` (`terraform output`). A porta 6901 também está liberada.

## Destruir a infraestrutura

```bash
cd terraform
terraform plan -destroy -refresh=false   # confere o que será removido
terraform destroy -refresh=false
```

- O destroy remove apenas o que está no state: EC2, security group, key pair, buckets e o `kali-key.pem`. A VPC padrão não é afetada.
- Buckets com objetos não são removidos. Esvazie antes (`aws s3 rm s3://<bucket> --recursive`).

## Atenção

- **State local:** o `terraform.tfstate` fica em `terraform/` e não vai para o git. Se for perdido, o Terraform não sabe mais o que criou e os recursos ficam órfãos na AWS, gerando custo.
- **Segredos:** `.env`, `*.pem` e `*.tfstate*` estão no `.gitignore`. Nunca os commite. A chave privada também fica dentro do state.
- **Acesso aberto:** as portas 22 e 6901 aceitam `0.0.0.0/0`. Para restringir, passe `allowed_cidr_blocks` no módulo `ec2`.
