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

- `cache-init`: inicializa o diretório AOF e ajusta o volume para o UID/GID não-root do Redis (999:1000);
- `cache`: Redis local protegido por senha, executado como UID/GID 999:1000, com AOF, volume persistente e healthcheck;
- `api`: API NestJS gRPC como usuário não-root, JWT próprio e PostgreSQL externo; o healthcheck confirma que a porta gRPC está aceitando conexões;
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

A API deve possuir `.env` privado com PostgreSQL, Redis, JWT e e-mail. O frontend deve possuir seu próprio `.env` com `VITE_API_BASE_URL`. A infraestrutura não possui `.env` próprio: o Compose referencia diretamente os dois arquivos dos projetos irmãos.

## Configuração e execução

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\configurar-desenvolvimento.ps1
.\scripts\iniciar.ps1 -Aplicacao
```

Ou diretamente, sem `--env-file`:

```powershell
docker compose -f compose.yml --profile app up -d --build
```

O `compose.yml` carrega automaticamente `..\api_lixocerto\.env` para a API e o Redis, e o Dockerfile do frontend carrega `..\frontend_lixocerto\.env` durante o build do Vite.

O gateway só inicia depois que a API passa no healthcheck gRPC. Durante uma inicialização fria, consulte `docker compose -f compose.yml ps` e aguarde `healthy` para a API antes de investigar falhas de conexão; o healthcheck permite até três minutos para a primeira inicialização e não reinicia nem encerra a API.

## Fluxo integrado

```text
http://localhost:3000
        ↓
frontend Nginx :8080 → /api/rpc → Envoy :8080 → API gRPC :50051
                                                    ↓
                                          PostgreSQL externo + Redis
                                                    ↑
                              JWT próprio / papéis / permissões
```

O frontend utiliza somente `VITE_API_BASE_URL=/api/rpc`. Os segredos e credenciais permanecem exclusivamente no `.env` da API.

## Automação local e Postman

Para subir o ambiente, preparar os contratos, executar smoke tests e mostrar o estado:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

A preparação copia a definição raiz Protobuf, o ambiente e o catálogo de 26 métodos para `%USERPROFILE%\Postman\files\lixo-certo`. Ela não copia a coleção HTTP histórica. No Postman, use **New > gRPC**, `grpc://{{grpc_host}}` e **Save As** para criar a coleção nativa.

Para preencher o ambiente local do Postman usando a autenticação própria:

```powershell
.\scripts\obter-token-postman.ps1 -Email 'usuario@exemplo.test'
```

Em requisições protegidas, mantenha o metadado:

```text
authorization: Bearer {{jwt_token}}
```

## Segurança

As portas são vinculadas somente a `127.0.0.1`; os containers usam `no-new-privileges` e capabilities reduzidas. O frontend recebe apenas a variável pública `VITE_API_BASE_URL`; o Redis recebe o arquivo da API para obter sua senha de desenvolvimento. O server reflection deve ficar desabilitado em produção.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. Não execute testes destrutivos contra a base principal.

O serviço `cache` recebe `REDIS_PASSWORD` exclusivamente de `../api_lixocerto/.env` por meio de `env_file`. O serviço `cache-init` não recebe nem precisa de credenciais: ele somente prepara as permissões do volume persistente.

## Parada e limpeza

```powershell
.\scripts\parar.ps1
```

Para logs:

```powershell
.\scripts\logs.ps1 -Servico api
```

Não use `docker compose down -v` quando não quiser remover o volume local do Redis.
