# infrastructure

Infraestrutura como código (Terraform) do WineFlow na AWS.

## O que é provisionado

| Recurso        | Detalhes                                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------ |
| EC2 `kali`     | Ubuntu Server 22.04, `t3.medium`, SSD 30 GB (gp3), roda `scripts/kali-setup.sh` como `user_data` |
| Security Group | Entrada TCP nas portas 22 (SSH) e 6901 (KasmVNC do Kali)                                         |
| Chave SSH      | **Não é gerada pelo Terraform** — cada pessoa cria o próprio key pair na AWS e informa o nome    |
| S3             | 3 buckets: `wineflow-bronze-`, `wineflow-silver-` e `wineflow-gold-` + sufixo aleatório          |

Região: `us-east-1`. A rede usa a **VPC padrão** da conta. O módulo `terraform/modules/vpc` existe, mas não é usado no `main.tf`.

No primeiro boot, a EC2 sobe automaticamente dois containers Docker via `user_data` ([terraform/scripts/kali-setup.sh](terraform/scripts/kali-setup.sh)):
- `kali-lab`: desktop Kali Linux (KasmVNC, porta 6901, usuário `kasm_user` / senha `urubu100`), com Nmap, Autopsy, Sleuthkit e AWS CLI.
- `localstack-lab`: LocalStack mockando S3 e IAM, pra servir de alvo de testes controlado.

Os dois containers sobem com `--restart unless-stopped` — se a instância reiniciar, eles voltam sozinhos, sem precisar rodar nada manualmente de novo. O script só roda **uma vez**, no primeiro boot (comportamento padrão de `user_data`); se precisar reaplicar o script numa instância já existente, é preciso recriá-la (ver "Destruir a infraestrutura").

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
    │   └── vpc/            # existe, mas nao usado
    └── scripts/
        ├── deploy.ps1      # deploy no Windows
        ├── deploy.sh       # deploy no Linux
        ├── destroy.ps1     # destroy no Windows (so EC2/SG - ver secao de destroy)
        └── kali-setup.sh   # user_data da EC2 (Kali + LocalStack via Docker)
```

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- Credenciais AWS (no AWS Academy: _AWS Details_ > _AWS CLI_)
- Um key pair SSH já criado na sua conta AWS (console EC2 → Key Pairs, ou `aws ec2 create-key-pair`) — o Terraform não cria um pra você

## Configuração

1. Copie o modelo e preencha:

   ```bash
   cp .env.example .env
   ```

   ```env
   aws_access_key_id=
   aws_secret_access_key=
   aws_session_token=
   key_name=
   localstack_auth_token=
   ```

   - `key_name`: só o **nome** do key pair já cadastrado na AWS (não é caminho de arquivo nem nome do `.pem`). Deixe vazio pra subir sem acesso SSH.
   - `localstack_auth_token`: token opcional usado pelo container `localstack-lab`. Sem ele, os recursos mockados (S3, IAM) do LocalStack Community continuam funcionando normalmente — só fica sem features Pro.

2. No AWS Academy o token expira junto com a sessão do lab. Quando aparecer `ExpiredToken` ou erros de `AccessDenied` com `voc-cancel-cred`, reinicie o lab e atualize o `.env`.

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

No final, mostra o IP público da EC2 e os nomes dos buckets.

### Manualmente

Carregue as credenciais no ambiente e rode a partir de `terraform/`. **Sempre carregue o `.env` antes de rodar `terraform` direto** — um `terraform plan`/`apply` sem credenciais carregadas cai no profile AWS CLI padrão da sua máquina, que pode ser uma conta totalmente diferente da conta do Academy.

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

> **Por que `-refresh=false`?** No AWS Academy, uma SCP da organização nega `s3:GetBucketObjectLockConfiguration`, `s3:DeleteBucketEncryption`, `s3:DeletePublicAccessBlock` e `s3:DeleteBucket`. Por isso os buckets S3 não usam o recurso nativo `aws_s3_bucket` do provider — são criados via AWS CLI (`terraform/modules/s3/main.tf`, `null_resource` + `local-exec`), e o refresh dos demais recursos é desligado nos scripts pra evitar que o plan/apply/destroy falhe com **403 AccessDenied**. A consequência é que o Terraform não detecta alterações feitas fora dele, como mudanças manuais no console.

### Recursos órfãos (recriados fora do Terraform)

Se o security group ou a instância EC2 ficarem fora do state (por exemplo, uma apply anterior que falhou no meio), o `terraform plan` detecta automaticamente um recurso já existente com o mesmo nome/tag na AWS e o **adota** via `import` block (ver `terraform/main.tf`), em vez de tentar criar um duplicado. Buckets S3 funcionam de forma parecida, mas via busca por prefixo (`terraform/modules/s3/main.tf`) — como `create-bucket`/`put-bucket-encryption`/`put-public-access-block` são idempotentes na AWS, não há risco em rodar de novo contra um bucket que já existe.

## Acessar a EC2

**Kali Linux (desktop, via navegador):** `https://<kali_public_ip>:6901` — usuário `kasm_user`, senha `urubu100`. Se der erro 401, use uma janela anônima.

**SSH:**

```bash
ssh -i /caminho/para/sua-chave.pem ubuntu@<kali_public_ip>
```

Use o arquivo `.pem` que você baixou ao criar seu key pair na AWS (não é gerado nem gerenciado pelo Terraform). O IP aparece no output `kali_public_ip` (`terraform output`) e pode mudar entre sessões (não é um IP fixo/Elastic IP).

## Destruir a infraestrutura

**Pelo script (Windows, recomendado):**

```powershell
.\terraform\scripts\destroy.ps1
```

**Manualmente:**

```bash
cd terraform
terraform plan -destroy -refresh=false   # confere o que será removido
terraform destroy -refresh=false
```

- **Os buckets S3 nunca são destruídos** (nem pelo script, nem manualmente) — a SCP do AWS Academy nega `s3:DeleteBucket`, então não há como apagá-los por aqui. `destroy.ps1` já exclui o módulo `s3` do destroy (`-target=module.ec2`) por esse motivo. Eles ficam até o lab do Academy expirar/resetar.
- O destroy remove apenas o que está no state: a instância EC2 e o security group. O key pair SSH (criado manualmente fora do Terraform) e a VPC padrão não são afetados.

## Atenção

- **State local:** o `terraform.tfstate` fica em `terraform/` e não vai para o git. Se for perdido, o Terraform não sabe mais o que criou e os recursos ficam órfãos na AWS, gerando custo.
- **Segredos:** `.env` e `*.tfstate*` estão no `.gitignore`. Nunca os commite.
- **Acesso aberto:** as portas 22 e 6901 aceitam `0.0.0.0/0`. Para restringir, passe `allowed_cidr_blocks` no módulo `ec2`.
- **Credenciais erradas:** rodar `terraform`/`aws` sem carregar o `.env` usa o profile AWS CLI padrão da sua máquina, que pode ser uma conta pessoal diferente da conta do Academy — sempre carregue o `.env` (ou use os scripts) antes de qualquer comando que fale com a AWS.
