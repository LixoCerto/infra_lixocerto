# Infra Lixo Certo

Projeto responsável pela infraestrutura Docker de desenvolvimento do ecossistema Lixo Certo. A API e o frontend não mantêm Dockerfiles próprios; as imagens e a orquestração ficam centralizadas aqui.

## Estrutura

```text
infra_lixocerto/
├── compose.yml
├── docker/
│   ├── api.Dockerfile
│   ├── api.Dockerfile.dockerignore
│   ├── frontend.Dockerfile
│   └── frontend.Dockerfile.dockerignore
├── scripts/
└── docs/
```

Os contextos de build são os projetos irmãos `api_lixocerto` e `frontend_lixocerto`. Assim, os Dockerfiles permanecem neste repositório sem duplicar arquivos de infraestrutura nos projetos de aplicação.

## Responsabilidades

- `cache`: Redis local protegido por senha, AOF, volume persistente e healthcheck;
- `api`: imagem multi-stage da API NestJS gRPC, executada como usuário não-root;
- `frontend`: imagem multi-stage do servidor Node de produção do frontend, executada como usuário não-root;
- PostgreSQL: banco externo, configurado no `.env` da API e nunca criado por este Compose.

## Pré-requisitos

- Docker Desktop com Docker Compose v2;
- os três projetos clonados como pastas irmãs:

```text
G:\LixoCerto\infra_lixocerto
G:\LixoCerto\api_lixocerto
G:\LixoCerto\frontend_lixocerto
```

- `.env` real da API contendo o PostgreSQL externo;
- senha local do Redis somente no `.env` desta infraestrutura.

## Configuração

No PowerShell:

```powershell
cd G:\LixoCerto\infra_lixocerto
Copy-Item .env.exemplo .env
notepad .env
```

Defina `REDIS_PASSWORD`. O arquivo real é ignorado pelo Git.

## Perfis de execução

### Somente Redis

```powershell
docker compose --env-file .env -f compose.yml up -d cache
docker compose --env-file .env -f compose.yml ps
```

### Redis e aplicações em containers

```powershell
docker compose --env-file .env -f compose.yml --profile app up -d --build
```

Esse perfil:

1. inicia o Redis;
2. aguarda o healthcheck do Redis;
3. constrói e inicia a API na porta `50051`;
4. inicia o frontend na porta `3000`.

A API recebe `URL_REDIS=redis://:senha@cache:6379` internamente e mantém `URL_BANCO_DADOS` vindo do arquivo `.env` da API, apontando para o PostgreSQL externo.

### Scripts PowerShell

```powershell
.\scripts\iniciar.ps1
.\scripts\status.ps1
.\scripts\logs.ps1
.\scripts\parar.ps1
```

Para iniciar também API e frontend:

```powershell
.\scripts\iniciar.ps1 -Aplicacao
```

## Parada e limpeza

Parar sem remover dados:

```powershell
docker compose --env-file .env -f compose.yml stop
```

Remover containers e rede, preservando o Redis:

```powershell
docker compose --env-file .env -f compose.yml down
```

Remover deliberadamente o volume Redis:

```powershell
docker compose --env-file .env -f compose.yml down -v
```

## Segurança

- portas vinculadas somente a `127.0.0.1`;
- Redis exige senha;
- containers usam `no-new-privileges`;
- capabilities são removidas;
- processos da API e frontend usam usuário não-root;
- arquivos `.env`, tokens, chaves e dados persistentes não são versionados;
- o Dockerfile-specific ignore exclui dependências, builds, logs e segredos dos contextos.

## PostgreSQL externo

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. A API usa, no próprio arquivo de ambiente:

```env
URL_BANCO_DADOS=postgres://postgres:SENHA_CODIFICADA@177.223.51.10:5432/lixocerto
```

Antes de executar migrations, confirme que o banco remoto está preparado e possui as extensões necessárias. Não execute testes de integração contra o banco principal.
