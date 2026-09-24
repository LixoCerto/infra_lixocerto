# Arquitetura de infraestrutura

## Projetos

| Projeto | Responsabilidade | Docker próprio |
|---|---|---:|
| `api_lixocerto` | API gRPC, migrations, regras de negócio e integração com PostgreSQL/Redis | Não |
| `frontend_lixocerto` | Interface web e cliente gRPC-Web/Connect | Não |
| `infra_lixocerto` | Orquestração Docker de desenvolvimento e Redis local | Sim |

## Dependências

A API usa o PostgreSQL externo informado em `URL_BANCO_DADOS` e o Redis local iniciado por este projeto. O frontend acessa a API pela porta gRPC/gateway configurado, mas não conhece credenciais de banco ou Redis.

## Princípios operacionais

O Compose expõe o Redis somente em loopback, exige senha, habilita AOF, mantém volume nomeado, usa healthcheck, reinício automático, limite de logs e redução de capabilities do container. O projeto de infraestrutura não contém senhas reais, dumps de banco nem arquivos `.env` versionados.

## Limites

O projeto não executa migrations automaticamente, não contém o PostgreSQL externo, não publica portas públicas e não armazena segredos. A preparação do banco remoto deve ser feita pelo administrador da infraestrutura correspondente.
