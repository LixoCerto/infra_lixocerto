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
├── tools/
└── docs/
```

Os contextos de build são os projetos irmãos `api_lixocerto` e `frontend_lixocerto`. O Dockerfile do frontend compila o Vite e entrega apenas arquivos estáticos pelo Nginx; o backend do frontend foi removido.

## Responsabilidades

O serviço `cache` executa Redis local protegido por senha, AOF, volume persistente e healthcheck. O serviço `api` executa a API NestJS gRPC como usuário não-root e conecta-se ao PostgreSQL externo. O `gateway` converte gRPC-Web do navegador para gRPC na API. O `frontend` entrega o bundle React/Vite pelo Nginx, sem Node em runtime e sem banco próprio.

## Pré-requisitos

É necessário ter Docker Desktop com Docker Compose v2 e os três projetos clonados como pastas irmãs:

```text
G:\LixoCerto\infra_lixocerto
G:\LixoCerto\api_lixocerto
G:\LixoCerto\frontend_lixocerto
```

A API deve possuir `.env` privado com o PostgreSQL externo. A infraestrutura usa `.env` próprio para a senha local do Redis e as variáveis públicas OIDC do bundle frontend.

## Configuração e execução

No PowerShell:

```powershell
cd G:\LixoCerto\infra_lixocerto
Copy-Item .env.exemplo .env
notepad .env
```

Defina `REDIS_PASSWORD`, `VITE_OIDC_ISSUER` e `VITE_OIDC_CLIENT_ID`. Os valores `VITE_*` são públicos no bundle e não podem conter segredos. Para o ambiente local do Postman, mantenha `HABILITAR_REFLECTION_GRPC=true`; essa configuração é bloqueada pela API quando o ambiente é produção.

Para iniciar somente o Redis:

```powershell
docker compose --env-file .env -f compose.yml up -d cache
```

Para iniciar Redis, API, gateway e frontend:

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

## Automação local e Postman

Para subir o ambiente, preparar os contratos e o catálogo gRPC, e executar os smoke tests em uma única operação:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

A preparação copia os contratos, a definição raiz `Lixo-Certo-API.postman.proto`, o ambiente e o catálogo de 22 métodos para `%USERPROFILE%\Postman\files\lixo-certo`. Ela não copia a coleção JSON HTTP legada. No Postman, use **New > gRPC**, `grpc://{{grpc_host}}` e **Save As** para criar a coleção nativa `Lixo Certo — API gRPC — Nativa`. Com reflection habilitada, o Postman descobre automaticamente os serviços e métodos; sem reflection, importe a definição raiz.

O arquivo `Lixo-Certo-API.grpc.manifest.json` não é uma Collection JSON importável. Ele é um catálogo de configuração deliberadamente marcado como não importável, porque o Postman não fornece atualmente um formato público e confiável para serializar requests gRPC nativos em Collection v2.1. A coleção HTTP histórica foi movida para `api_lixocerto/docs/postman/legado/` e não deve ser usada como gRPC.

Consulte [docs/AUTOMACAO_LOCAL.md](docs/AUTOMACAO_LOCAL.md) e [docs/REFERENCIAS_POSTMAN_GRPC.md](docs/REFERENCIAS_POSTMAN_GRPC.md) para o procedimento completo e as fontes oficiais.

## Segurança

As portas são vinculadas somente a `127.0.0.1`; Redis exige senha; o gateway não publica a administração do Envoy; os containers usam `no-new-privileges` e capabilities reduzidas; a API e o Nginx não recebem o `.env` privado do frontend; e os Dockerfiles copiam somente os diretórios necessários. O server reflection é uma facilidade local e não deve ser habilitado em produção.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. Não execute testes de integração contra a base principal.

## Parada e limpeza

```powershell
.\scripts\parar.ps1
```

Para acompanhar logs:

```powershell
.\scripts\logs.ps1 -Servico api
.\scripts\logs.ps1 -Servico gateway
```

Para remover deliberadamente o volume Redis, use `docker compose --env-file .env -f compose.yml down -v` somente quando essa perda local for desejada.
