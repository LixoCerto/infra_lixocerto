# Infra Lixo Certo

Projeto responsável pela infraestrutura Docker de desenvolvimento do ecossistema Lixo Certo. A API e o frontend não mantêm Dockerfiles próprios; imagens, gateway e orquestração ficam centralizados aqui.

## Estrutura

```text
infra_lixocerto/
├── compose.yml
├── docker/
│   ├── api.Dockerfile
│   ├── frontend.Dockerfile
│   └── envoy.yaml
├── scripts/
└── docs/
```

Os contextos de build são os projetos irmãos `api_lixocerto` e `frontend_lixocerto`. O Dockerfile do frontend compila o Vite e entrega apenas arquivos estáticos pelo Nginx; o backend do frontend foi removido.

## Responsabilidades

- `cache`: Redis local protegido por senha, AOF, volume persistente e healthcheck;
- `api`: imagem multi-stage da API NestJS gRPC, executada como usuário não-root e conectada ao PostgreSQL externo;
- `gateway`: Envoy com filtro gRPC-Web, CORS controlado e encaminhamento HTTP/2 para a API;
- `frontend`: bundle React/Vite servido pelo Nginx, sem Node em runtime e sem banco próprio.

## Pré-requisitos

- Docker Desktop com Docker Compose v2;
- os três projetos clonados como pastas irmãs:

```text
G:\LixoCerto\infra_lixocerto
G:\LixoCerto\api_lixocerto
G:\LixoCerto\frontend_lixocerto
```

- `.env` real da API contendo o PostgreSQL externo;
- senha local do Redis e variáveis públicas OIDC somente no `.env` desta infraestrutura.

## Configuração

No PowerShell:

```powershell
cd G:\LixoCerto\infra_lixocerto
Copy-Item .env.exemplo .env
notepad .env
```

Defina `REDIS_PASSWORD`, `VITE_OIDC_ISSUER` e `VITE_OIDC_CLIENT_ID`. Os valores `VITE_*` são públicos no bundle e não podem conter segredos.

## Execução

### Somente Redis

```powershell
docker compose --env-file .env -f compose.yml up -d cache
docker compose --env-file .env -f compose.yml ps
```

### Redis, API, gateway e frontend

```powershell
docker compose --env-file .env -f compose.yml --profile app up -d --build
```

O fluxo integrado é:

```text
http://localhost:3000
        ↓
frontend Nginx :8080 → /api/rpc → Envoy :8080 → API gRPC :50051
                                                    ↓
                                          PostgreSQL externo + Redis
```

A API recebe `URL_REDIS=redis://:senha@cache:6379` internamente e mantém `URL_BANCO_DADOS` vindo do arquivo privado da API.

### Scripts PowerShell

```powershell
.\scripts\iniciar.ps1
.\scripts\status.ps1
.\scripts\logs.ps1
.\scripts\parar.ps1
```

Para iniciar também API, Envoy e frontend:

```powershell
.\scripts\iniciar.ps1 -Aplicacao
```

## Parada e limpeza

```powershell
docker compose --env-file .env -f compose.yml stop
docker compose --env-file .env -f compose.yml down
```

Para remover deliberadamente o volume Redis:

```powershell
docker compose --env-file .env -f compose.yml down -v
```

## Segurança

- portas vinculadas somente a `127.0.0.1`;
- Redis exige senha;
- gateway não publica administração do Envoy;
- containers usam `no-new-privileges` e capabilities reduzidas;
- API e Nginx não recebem o `.env` privado do frontend;
- os Dockerfiles copiam somente os diretórios necessários para evitar incluir ambientes locais.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. Não execute testes de integração contra o banco principal.

## Automação híbrida

Para subir o ambiente, aguardar os healthchecks, preparar os contratos no diretório de trabalho do Postman e executar os smoke tests gRPC públicos em uma única operação:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

O runner cria `reports\grpc-smoke.json` e valida saúde, materiais, pontos de coleta, questões e ranking. O Postman continua disponível para inspeção visual e chamadas autenticadas, mas a validação básica não depende da interface do Postman. Consulte [docs/AUTOMACAO_LOCAL.md](docs/AUTOMACAO_LOCAL.md) para o fluxo completo.
