# LixoCerto — Infraestrutura

Este repositório concentra Docker Compose, imagens, Envoy e scripts operacionais da plataforma **LixoCerto**. A stack apoia desenvolvimento e integração entre os serviços; sua presença não declara prontidão para produção nem validação de todos os fluxos no ambiente de hospedagem.

## Visão da arquitetura

```text
Navegador
   │
   ▼
Frontend React / Nginx :3000
   │ /api/rpc
   ▼
Envoy gRPC-Web :8080
   │ gRPC
   ▼
API NestJS :50051 ─── PostgreSQL externo
   ├───────────────── Redis
   └───────────────── MinIO / API compatível com S3
```

As portas publicadas pelo Compose ficam vinculadas a `127.0.0.1`. A camada TLS e o proxy público, quando utilizados, são responsabilidade do ambiente de hospedagem e não são criados por este Compose.

## Repositórios e estrutura

Os três repositórios precisam estar lado a lado:

```text
LixoCerto/
├── api_lixocerto/
├── frontend_lixocerto/
└── infra_lixocerto/
```

Os contextos de build do `compose.yml` apontam para `../api_lixocerto` e `../frontend_lixocerto`; execute os comandos de Compose a partir da pasta `infra_lixocerto`.

Documentação e instruções de cada componente: [API](https://github.com/LixoCerto/api_lixocerto) · [Frontend web](https://github.com/LixoCerto/frontend_lixocerto).

```text
infra_lixocerto/
├── compose.yml
├── docker/       # Dockerfiles, Envoy e bootstrap MinIO
├── scripts/      # configuração, inicialização, logs, testes e parada
├── docs/         # arquitetura, automação e procedimentos específicos
└── PrepararMinio.ps1
```

## Serviços e perfis

| Serviço | Função |
|---|---|
| `cache-init` / `cache` | Prepara o volume e executa Redis com senha, AOF e healthcheck. |
| `minio-data-init` / `minio` | Prepara o volume e fornece armazenamento S3 local para evidências. |
| `minio-bootstrap` | Cria e valida bucket, identidade de aplicação e política; é uma etapa one-shot. |
| `api` | API NestJS gRPC; conecta-se ao PostgreSQL externo e aos serviços locais. |
| `gateway` | Envoy converte gRPC-Web do navegador em gRPC para a API. |
| `frontend` | Bundle React servido por Nginx não privilegiado. |
| `evidencia-migration` | Ferramenta de manutenção opcional para migração de evidências legadas; não faz parte do perfil normal da aplicação. |

O perfil padrão contém o Redis. `--profile app` habilita a aplicação integrada. `--profile maintenance` é reservado a procedimentos de manutenção documentados. O PostgreSQL **não** está no Compose; forneça uma instância acessível pela API.

## Requisitos

- Docker Engine ou Docker Desktop com Docker Compose v2;
- PowerShell para os scripts `.ps1` incluídos; os comandos diretos de Compose podem ser executados no shell do sistema;
- os três repositórios clonados como pastas irmãs;
- PostgreSQL de desenvolvimento/teste acessível antes de iniciar a API.

## Preparar a configuração local

Crie os arquivos de configuração privados somente se ainda não existirem, usando os exemplos dos repositórios correspondentes:

```powershell
if (-not (Test-Path ..\api_lixocerto\.env)) {
  Copy-Item ..\api_lixocerto\.env.exemplo ..\api_lixocerto\.env
}
if (-not (Test-Path ..\frontend_lixocerto\.env)) {
  Copy-Item ..\frontend_lixocerto\.env.exemplo ..\frontend_lixocerto\.env
}
```

Preencha os valores do banco, Redis, JWT, e-mail e origens autorizadas no `.env` privado da API. No `.env` do frontend, `VITE_API_BASE_URL` deve ser `/api/rpc` para a stack Docker. Se o botão Google for usado, configure também o Client ID web público em `VITE_GOOGLE_CLIENT_ID` e o mesmo Client ID em `GOOGLE_OAUTH_CLIENT_ID` na API.

O script `scripts/configurar-desenvolvimento.ps1` valida os arquivos principais e cria `./.env.redis` com somente `REDIS_PASSWORD`, sem mostrar a senha. Ao iniciar a aplicação, `PrepararMinio.ps1` cria `./.env.minio-root` e `./.env.storage-app` se ambos estiverem ausentes. Se apenas um dos dois existir, o script para para não sobrescrever uma configuração parcial.

**Nunca versione `.env`, `.env.redis`, `.env.minio-root` ou `.env.storage-app`.** `VITE_*` é configuração pública incorporada ao bundle; não coloque segredos nessas variáveis.

## Inicialização integrada

A partir da pasta `infra_lixocerto`, no PowerShell:

```powershell
.\scripts\iniciar.ps1 -Aplicacao
```

O inicializador prepara a configuração, constrói as imagens e executa o bootstrap do MinIO antes da API. Em seguida, inicia Redis, aguarda a API ficar saudável e sobe Envoy e frontend. Se o bootstrap falhar, a API não é iniciada.

Para preparar arquivos de apoio e executar verificações gRPC:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

O smoke autenticado é opcional e requer uma conta de teste e as variáveis de runner documentadas pelo script:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -SmokeTests -SmokeAutenticado
```

Para subir somente o Redis local, sem iniciar a aplicação:

```powershell
.\scripts\iniciar.ps1
```

## Portas locais

| Serviço | Endereço no host | Observação |
|---|---|---|
| Frontend | `http://127.0.0.1:3000` | Nginx com SPA |
| Envoy | `http://127.0.0.1:8080` | Endpoint gRPC-Web usado pelo Vite local |
| API | `127.0.0.1:50051` | gRPC |
| Redis | `127.0.0.1:6379` | Protegido por senha |
| MinIO API | `127.0.0.1:9000` | Armazenamento S3 local |
| MinIO Console | `http://127.0.0.1:9001` | Console administrativo local |

## Banco de dados e migrations

O Compose não inicializa, migra nem remove PostgreSQL. Antes de rodar uma migration, confirme que o `.env` aponta para a base correta e faça backup. Em desenvolvimento, uma migration pode ser executada manualmente a partir do repositório de infraestrutura:

```powershell
docker compose -f compose.yml --profile app build api
docker compose -f compose.yml --profile app run --rm --no-deps api node_modules/.bin/sequelize-cli db:migrate --config configuracao_sequelize.cjs --migrations-path banco/migracoes
```

Os seeds também são manuais e devem ser executados apenas em bases próprias de desenvolvimento/homologação. Não use `down -v`, migrations de desenvolvimento ou seeds contra uma base importante sem um procedimento de backup e revisão.

A migração de evidências legadas é outro procedimento, separado da inicialização normal. Consulte [`docs/MIGRACAO_MINIO_EVIDENCIAS.md`](docs/MIGRACAO_MINIO_EVIDENCIAS.md) antes de usar o perfil `maintenance`.

## Operação cotidiana

```powershell
.\scripts\status.ps1
.\scripts\logs.ps1 -Servico api
.\scripts\parar.ps1
```

Os comandos Compose equivalentes, a partir da pasta de infraestrutura, incluem:

```bash
docker compose --profile app ps
docker compose --profile app logs -f api
docker compose --profile app down
```

`down` preserva os volumes nomeados. Não acrescente `-v` a menos que a remoção permanente dos dados locais seja intencional.

## Segurança e limitações

- Os serviços são publicados no loopback; não exponha diretamente portas internas à Internet.
- O Redis recebe apenas o arquivo local `./.env.redis`; o frontend recebe apenas configuração pública.
- MinIO e credenciais da aplicação permanecem em arquivos locais ignorados pelo Git.
- gRPC reflection deve permanecer desativada fora dos cenários em que for intencionalmente necessária.
- As migrations são uma etapa explícita; o Compose não as executa automaticamente.
- Testes de healthcheck e smoke não equivalem a auditoria de segurança, teste ponta a ponta com participantes ou garantia de prontidão para produção.

## Documentação relacionada

- [Arquitetura da infraestrutura](docs/ARQUITETURA.md)
- [Automação local](docs/AUTOMACAO_LOCAL.md)
- [Migração de evidências para MinIO](docs/MIGRACAO_MINIO_EVIDENCIAS.md)
- [Referências gRPC/Postman](docs/REFERENCIAS_POSTMAN_GRPC.md)
