# Arquitetura de infraestrutura

## Projetos

| Projeto | Responsabilidade | Docker próprio |
|---|---|---:|
| `api_lixocerto` | API gRPC, migrations, regras de negócio, PostgreSQL e Redis | Não |
| `frontend_lixocerto` | Interface React/Vite estática, cliente gRPC-Web e layout adaptativo | Não |
| `infra_lixocerto` | Dockerfiles, Compose, Envoy, Redis local e operação | Sim |

## Imagens

- `docker/api.Dockerfile`: compila a API NestJS e inicia `dist/src/principal.js` como usuário não-root na porta `50051`;
- `docker/frontend.Dockerfile`: compila o frontend Vite e entrega o diretório `dist` pelo Nginx unprivileged na porta `8080`;
- `envoyproxy/envoy`: recebe gRPC-Web na porta `8080`, aplica CORS e encaminha HTTP/2 para a API gRPC.

Os contextos de build são os diretórios irmãos das aplicações. Os Dockerfiles fazem cópia explícita dos diretórios necessários, impedindo que `.env` e artefatos locais entrem nas imagens.

## Fluxo

```text
navegador :3000
    ↓ HTTP estático e /api/rpc
frontend Nginx :8080
    ↓ gRPC-Web
Envoy :8080
    ↓ gRPC/HTTP2
API :50051
    ├── PostgreSQL externo
    └── Redis :6379
```

## Perfis

Sem perfil, o Compose inicia somente o Redis. Com `--profile app`, inicia Redis, API, gateway e frontend; as portas publicadas permanecem vinculadas ao loopback local.

## Princípios operacionais

O Redis exige senha, habilita AOF, mantém volume nomeado, usa healthcheck, reinício automático e limite de logs. A API e o Nginx usam imagens multi-stage. O projeto não contém PostgreSQL, senhas reais, dumps, tokens ou arquivos de ambiente versionados.

## Limites

O projeto não executa migrations automaticamente, não publica portas públicas e não armazena segredos. A preparação do banco remoto e a configuração do `SEGREDO_JWT` devem ser feitas pelo administrador responsável.
