# Infra Lixo Certo

Projeto responsável pela infraestrutura Docker de desenvolvimento do ecossistema Lixo Certo. A API e o frontend não mantêm mais Compose, Dockerfile ou gestão de containers próprios.

## Escopo

Este projeto gerencia exclusivamente o Redis local usado pela API. O PostgreSQL da aplicação é externo e permanece configurado no `.env` da API por meio de `URL_BANCO_DADOS`. Nenhum banco externo é criado, destruído ou migrado por este Compose.

## Pré-requisitos

- Docker Desktop com Docker Compose v2;
- API Lixo Certo clonada ao lado deste projeto;
- Credenciais do Redis somente no arquivo `.env` local.

## Configuração

No PowerShell:

```powershell
Copy-Item .env.exemplo .env
notepad .env
```

Defina uma senha local forte em `REDIS_PASSWORD`. O arquivo `.env` é ignorado pelo Git.

## Operação

```powershell
# Iniciar o Redis
.\scripts\iniciar.ps1

# Conferir saúde e portas
.\scripts\status.ps1

# Acompanhar logs
.\scripts\logs.ps1

# Parar sem remover dados
.\scripts\parar.ps1
```

Comandos equivalentes:

```powershell
docker compose --env-file .env -f .\compose.yml up -d
docker compose --env-file .env -f .\compose.yml ps
docker compose --env-file .env -f .\compose.yml exec -T cache redis-cli -a $env:REDIS_PASSWORD ping
docker compose --env-file .env -f .\compose.yml stop
docker compose --env-file .env -f .\compose.yml logs -f --tail=100 cache
```

A porta fica vinculada somente a `127.0.0.1`, e o volume persistente chama-se `lcr-redis-data`. Para destruir deliberadamente os dados locais:

```powershell
docker compose --env-file .env -f .\compose.yml down -v
```

## Integração com a API

Na API, mantenha o PostgreSQL externo e a URL do Redis local protegida por senha:

```env
URL_BANCO_DADOS=postgres://postgres:SENHA_CODIFICADA@177.223.51.10:5432/lixocerto
URL_REDIS=redis://:SENHA_REDIS@127.0.0.1:6379
URL_REDIS_TESTE=redis://:SENHA_REDIS@127.0.0.1:6379/15
```

A senha do Redis deve ser codificada na URL quando possuir caracteres reservados. Não copie a senha do `.env` para o GitHub, Postman, frontend ou logs.

## Ordem de inicialização

```text
infra_lixocerto: Redis local
        ↓
api_lixocerto: PostgreSQL externo + Redis local
        ↓
frontend_lixocerto: cliente web
```

O PostgreSQL externo não é administrado por este projeto. Migrations e seeds continuam sendo comandos explícitos da API e devem ser executados somente quando o banco remoto estiver preparado.
