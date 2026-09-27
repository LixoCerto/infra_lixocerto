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

- `cache`: Redis local protegido por senha, AOF, volume persistente e healthcheck;
- `api`: API NestJS gRPC como usuário não-root, JWT próprio e PostgreSQL externo;
- `gateway`: Envoy converte gRPC-Web do navegador para gRPC na API;
- `frontend`: bundle React/Vite servido pelo Nginx, sem Node em runtime e sem banco próprio.

A autenticação é própria da API. Não há Keycloak, OIDC ou Mailpit no Compose atual.

## Pré-requisitos

É necessário ter Docker Desktop com Docker Compose v2 e os três projetos clonados como pastas irmãs:

```text
G:\LixoCerto\infra_lixocerto
G:\LixoCerto\api_lixocerto
G:\LixoCerto\frontend_lixocerto
```

A API deve possuir `.env` privado com o PostgreSQL externo. A infraestrutura usa `.env` próprio para Redis, `SEGREDO_JWT` e variáveis públicas do bundle frontend. O script de configuração não altera a URL do PostgreSQL.

## Configuração e execução

No PowerShell:

```powershell
cd G:\LixoCerto\infra_lixocerto
.\scripts\configurar-desenvolvimento.ps1
docker compose --env-file .env -f compose.yml --profile app up -d --build
```

O fluxo integrado é:

```text
http://localhost:3000
        ↓
frontend Nginx :8080 → /api/rpc → Envoy :8080 → API gRPC :50051
                                                    ↓
                                          PostgreSQL externo + Redis
                                                    ↑
                              JWT próprio / papéis / permissões
```

A API recebe `URL_REDIS=redis://:senha@cache:6379` internamente, assina e valida JWT com `SEGREDO_JWT` e mantém `URL_BANCO_DADOS` vindo do arquivo privado da API.

## Automação local e Postman

Para subir o ambiente, preparar os contratos, executar smoke tests e mostrar o estado:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

A preparação copia a definição raiz Protobuf, o ambiente e o catálogo de 26 métodos para `%USERPROFILE%\Postman\files\lixo-certo`. Ela não copia a coleção HTTP histórica. No Postman, use **New > gRPC**, `grpc://{{grpc_host}}` e **Save As** para criar a coleção nativa. O manifesto é catálogo, não Collection JSON importável.

Para preencher o ambiente local do Postman usando a autenticação própria:

```powershell
.\scripts\obter-token-postman.ps1 -Email 'usuario@exemplo.test'
```

O script solicita a senha sem colocá-la na linha de comando, chama `Entrar` pelo gRPC e grava os tokens somente no arquivo local do Postman. Em requisições protegidas, mantenha o metadado:

```text
authorization: Bearer {{jwt_token}}
```

## Segurança

As portas são vinculadas somente a `127.0.0.1`; os containers usam `no-new-privileges` e capabilities reduzidas; a API e o Nginx não recebem o `.env` privado do frontend; e os Dockerfiles copiam somente os diretórios necessários. O server reflection é facilidade de desenvolvimento local e deve ficar desabilitado em produção.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. Não execute testes destrutivos contra a base principal.

## Parada e limpeza

```powershell
.\scripts\parar.ps1
```

Para logs:

```powershell
.\scripts\logs.ps1 -Servico api
.\scripts\logs.ps1 -Servico gateway
```

Não use `down -v` quando não quiser remover o volume local do Redis.
