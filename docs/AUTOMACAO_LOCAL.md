# Automação local — Lixo Certo

## Objetivo

O projeto de infraestrutura fornece um fluxo híbrido e reproduzível. O Docker sobe Redis, API, gateway e frontend; um runner gRPC verifica automaticamente as dependências e os principais métodos públicos; o Postman recebe os contratos e arquivos de ambiente no diretório de trabalho local para inspeção visual.

O Postman continua sendo usado para depuração interativa. A validação automática não depende da interface do Postman, porque a importação de uma coleção JSON v2.1 pode representar itens gRPC como POST genérico em algumas versões do cliente.

## Execução completa no Windows

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Esse comando:

1. cria `.env` a partir de `.env.exemplo` caso necessário;
2. constrói e inicia os quatro serviços do Compose;
3. aguarda Redis, API, gateway e frontend;
4. copia contratos `.proto`, coleção e ambiente para `%USERPROFILE%\Postman\files\lixo-certo`;
5. executa cinco smoke tests gRPC públicos;
6. grava `reports\grpc-smoke.json`.

## Execução por etapas

Subir a aplicação:

```powershell
.\scripts\iniciar.ps1 -Aplicacao
```

Preparar os arquivos do Postman:

```powershell
.\scripts\preparar-postman.ps1
```

Executar os smoke tests:

```powershell
pnpm install --frozen-lockfile
pnpm smoke:grpc
```

O runner testa:

- `ServicoSaude/Verificar`, exigindo serviço, PostgreSQL e Redis disponíveis;
- `ServicoMateriais/ListarMateriais`;
- `ServicoPontosColeta/ListarPontosColeta`;
- `ServicoQuestionarios/ListarQuestoes`;
- `ServicoGamificacao/ObterRanking`.

Os métodos protegidos não são chamados automaticamente sem um token fornecido explicitamente. Para uma execução local autorizada:

```powershell
$env:GRPC_JWT_TOKEN = 'cole-o-apenas-na-sessão-local'
$env:GRPC_ID_USUARIO_EXTERNO = 'usuario-de-teste'
pnpm smoke:grpc
Remove-Item Env:\GRPC_JWT_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\GRPC_ID_USUARIO_EXTERNO -ErrorAction SilentlyContinue
```

O JWT nunca deve ser colocado no `.env`, na coleção, no ambiente versionado ou no relatório.

## Postman para inspeção

O script prepara:

```text
%USERPROFILE%\Postman\files\lixo-certo\contratos\lixo_certo\v1\
%USERPROFILE%\Postman\files\lixo-certo\Lixo-Certo-API.postman_collection.json
%USERPROFILE%\Postman\files\lixo-certo\Lixo-Certo-API.postman_environment.json
```

No Postman, selecione o ambiente `Lixo Certo — API local — gRPC`, crie uma requisição gRPC em `grpc://127.0.0.1:50051` e selecione o serviço pela definição Protobuf compartilhada. A preparação dos arquivos é automática; a criação/salvamento da requisição nativa no workspace do Postman continua sendo uma ação inicial do cliente.

## Parar o ambiente

```powershell
.\scripts\parar.ps1
```

Para acompanhar logs:

```powershell
.\scripts\logs.ps1 -Servico api
.\scripts\logs.ps1 -Servico gateway
```

## Resultado esperado

```text
Smoke gRPC: 5/5 aprovados em 127.0.0.1:50051
Relatório: reports/grpc-smoke.json
```

O PostgreSQL externo não é criado nem destruído pelo Compose. O smoke test apenas confirma sua disponibilidade por meio do método de saúde da API.

Para repetir somente a validação gRPC depois que os containers já estiverem ativos:

```powershell
.\scripts\testar.ps1
```

É possível alterar o endereço e timeout:

```powershell
.\scripts\testar.ps1 -HostGrpc '127.0.0.1:50051' -TimeoutMilissegundos 8000
```
