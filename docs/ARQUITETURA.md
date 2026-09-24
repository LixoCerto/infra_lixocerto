# Arquitetura de infraestrutura

## Projetos

| Projeto | Responsabilidade | Docker próprio |
|---|---|---:|
| `api_lixocerto` | API gRPC, migrations, regras de negócio e integração com PostgreSQL/Redis | Não |
| `frontend_lixocerto` | Interface web e cliente gRPC-Web/Connect | Não |
| `infra_lixocerto` | Dockerfiles, Compose, Redis local e operação dos containers | Sim |

## Imagens

O projeto de infraestrutura possui dois Dockerfiles multi-stage:

- `docker/api.Dockerfile`: compila a API NestJS, copia contratos Protobuf para o runtime e inicia `dist/src/principal.js` como usuário não-root na porta `50051`;
- `docker/frontend.Dockerfile`: compila o frontend Vite/Express, inicia `dist/index.js` como usuário não-root na porta `3000`.

Os contextos de build são os diretórios irmãos das aplicações. Os arquivos `*.Dockerfile.dockerignore` ficam junto aos Dockerfiles para excluir dependências, builds, logs e ambientes locais sem colocar artefatos Docker nos projetos de aplicação.

## Dependências

A API usa o PostgreSQL externo informado em `URL_BANCO_DADOS` e o Redis local iniciado pelo Compose. O frontend é servido pelo container Node e não recebe credenciais do banco PostgreSQL da API.

## Perfis

Sem perfil, o Compose inicia somente o Redis. Com `--profile app`, inicia Redis, API e frontend, mantendo as portas locais `50051` e `3000` vinculadas a loopback.

## Princípios operacionais

O Redis exige senha, habilita AOF, mantém volume nomeado, usa healthcheck, reinício automático, limite de logs e redução de capabilities do container. API e frontend usam imagens multi-stage e usuários não-root. O projeto de infraestrutura não contém senhas reais, dumps de banco nem arquivos de ambiente versionados.

## Limites

O projeto não executa migrations automaticamente, não contém o PostgreSQL externo, não publica portas públicas e não armazena segredos. A preparação do banco remoto deve ser feita pelo administrador da infraestrutura correspondente.
