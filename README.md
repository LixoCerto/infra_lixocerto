# Infra Lixo Certo

Projeto responsável pela infraestrutura Docker de desenvolvimento do ecossistema Lixo Certo. A API e o frontend não mantêm Dockerfiles próprios; imagens, gateway e orquestração ficam centralizados aqui.

## Estrutura

```text
infra_lixocerto/
├── compose.yml
├── docker/
│   ├── api.Dockerfile
│   ├── frontend.Dockerfile
│   ├── minio-bootstrap.sh
│   └── envoy.yaml
├── scripts/
├── tools/
└── docs/
```

Os contextos de build são os projetos irmãos `api_lixocerto` e `frontend_lixocerto`. O Dockerfile do frontend compila o Vite e entrega apenas arquivos estáticos pelo Nginx; o backend do frontend foi removido.

## Responsabilidades

- `cache-init`: inicializa o diretório AOF e ajusta o volume para o UID/GID não-root do Redis (999:1000);
- `cache`: Redis local protegido por senha, executado como UID/GID 999:1000, com AOF, volume persistente e healthcheck;
- `minio` e `minio-bootstrap`: armazenamento privado S3 local; o bootstrap provisiona e testa bucket, identidade e permissões antes de permitir a inicialização da API;
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

A API deve possuir `.env` privado com PostgreSQL, Redis, JWT e e-mail. O frontend deve possuir seu próprio `.env` com `VITE_API_BASE_URL`. A infraestrutura não possui `.env` próprio: o Compose referencia diretamente os dois arquivos dos projetos irmãos. A conexão e as credenciais do PostgreSQL não podem ser geradas pelo projeto; configure-as a partir dos exemplos, sem versionar os arquivos reais.

Em um clone novo, crie os arquivos privados somente se ainda não existirem e preencha os valores de desenvolvimento:

```powershell
if (-not (Test-Path ..\api_lixocerto\.env)) { Copy-Item ..\api_lixocerto\.env.exemplo ..\api_lixocerto\.env }
if (-not (Test-Path ..\frontend_lixocerto\.env)) { Copy-Item ..\frontend_lixocerto\.env.exemplo ..\frontend_lixocerto\.env }
notepad ..\api_lixocerto\.env
notepad ..\frontend_lixocerto\.env
```

Não compartilhe esses arquivos nem os adicione ao Git. O banco PostgreSQL deve estar disponível na rede do Docker antes de iniciar a aplicação.

## Configuração e execução

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\configurar-desenvolvimento.ps1
.\scripts\iniciar.ps1 -Aplicacao
```

Na primeira execução, `iniciar.ps1 -Aplicacao` gera os arquivos locais MinIO (sem sobrescrever configurações existentes), constrói as imagens, inicia MinIO, força uma nova execução do bootstrap e verifica bucket privado e operações S3 da API **antes** de iniciar API/gateway/frontend. Se o bootstrap falhar, a API não é iniciada. O PostgreSQL continua externo e as migrations/seeds permanecem uma etapa explícita, documentada abaixo; não execute esse fluxo apontando para uma base de produção.

O `compose.yml` carrega automaticamente `..\api_lixocerto\.env` para a API e o Redis, e o Dockerfile do frontend carrega `..\frontend_lixocerto\.env` durante o build do Vite. Para o primeiro start, use o inicializador em vez de iniciar serviços individualmente: ele confirma o resultado do bootstrap antes de subir a API.

O gateway só inicia depois que a API passa no healthcheck gRPC. Durante uma inicialização fria, consulte `docker compose -f compose.yml ps` e aguarde `healthy` para a API antes de investigar falhas de conexão; o healthcheck permite até três minutos para a primeira inicialização e não reinicia nem encerra a API.

## Migrações e seeds do banco

O Compose não aplica migrations automaticamente. Depois de atualizar o código, confirme primeiro que o `.env` privado da API aponta para o banco de desenvolvimento correto. Aplique a sequência abaixo: build das imagens alteradas, migrations/seeds em containers one-off da imagem nova e, só então, recriação da API/frontend. Os comandos de banco usam as mesmas variáveis do `.env` da API:

```powershell
docker compose -f compose.yml --profile app build --no-cache api frontend
docker compose -f compose.yml --profile app run --rm --no-deps api node_modules/.bin/sequelize-cli db:migrate --config configuracao_sequelize.cjs --migrations-path banco/migracoes
docker compose -f compose.yml --profile app run --rm --no-deps api node_modules/.bin/sequelize-cli db:seed:all --config configuracao_sequelize.cjs --seeders-path banco/dados_iniciais
docker compose -f compose.yml --profile app up -d --no-deps --force-recreate api frontend
```

O Dockerfile da API inclui migrations e seeds na imagem para esse uso manual. Os seeds devem ser idempotentes; não execute `db:seed:undo:all` nem migrations `down` para aplicar uma atualização normal.

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

O PostgreSQL externo não é criado nem destruído pelo Compose; migrations são sempre manuais. Não execute migrations de desenvolvimento nem testes destrutivos contra a base principal.

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
