# Automação local — Lixo Certo

## Objetivo

O projeto fornece um fluxo híbrido e reproduzível. O Docker sobe Redis, API, gateway e frontend; um runner gRPC verifica automaticamente os métodos públicos; o script do Postman prepara contratos, definição raiz, ambiente e catálogo para que o cliente Postman crie requisições gRPC nativas.

A distinção é importante: o Postman não trata um item Collection JSON v2.1 com `method: POST` e URL `grpc://` como uma requisição gRPC nativa. Por isso o fluxo não copia mais a coleção JSON legada e não promete uma importação que o cliente não suporta.

## Execução completa no Windows

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Esse comando cria o `.env` de infraestrutura caso necessário, constrói os quatro serviços Docker, aguarda os estados de saúde, habilita server reflection apenas no ambiente local, prepara os contratos no diretório do Postman e executa cinco smoke tests gRPC. O relatório é gravado em `reports\grpc-smoke.json`.

## Arquivos preparados para o Postman

O diretório padrão é `%USERPROFILE%\Postman\files\lixo-certo` e contém os contratos em `contratos\lixo_certo\v1\`, a definição raiz `Lixo-Certo-API.postman.proto`, o ambiente `Lixo-Certo-API.postman_environment.json`, o catálogo `Lixo-Certo-API.grpc.manifest.json` e uma cópia deste README. O catálogo possui os 22 serviços/métodos, mensagens e metadados, mas está marcado explicitamente como não importável como Collection JSON.

Se uma execução anterior deixou `Lixo-Certo-API.postman_collection.json` nesse diretório, o script o remove para impedir que um item HTTP `POST` seja confundido com gRPC nativo.

## Salvamento nativo no Postman

Após iniciar a aplicação, abra o Postman Desktop e selecione o ambiente `Lixo Certo — API local — gRPC`. Crie uma requisição por **New > gRPC**, use `grpc://{{grpc_host}}` e aguarde a lista de métodos carregada por server reflection. Se reflection não estiver disponível na versão instalada, importe `Lixo-Certo-API.postman.proto` pela aba **Service definition**.

Selecione cada método, use a mensagem e os metadados do catálogo e escolha **Save As** para a coleção `Lixo Certo — API gRPC — Nativa`. O botão de execução de uma chamada unary deve aparecer como **Invoke**. A coleção nativa não é criada pelo arquivo JSON legado: ela é persistida pelo cliente Postman, que atualmente não oferece um schema público e confiável para exportação/importação dessas requisições.

## Execução por etapas

Para subir a aplicação:

```powershell
.\scripts\iniciar.ps1 -Aplicacao
```

Para preparar ou atualizar os arquivos do Postman:

```powershell
.\scripts\preparar-postman.ps1
```

Para executar apenas os smoke tests:

```powershell
.\scripts\testar.ps1
```

Os testes cobrem `ServicoSaude/Verificar`, `ServicoMateriais/ListarMateriais`, `ServicoPontosColeta/ListarPontosColeta`, `ServicoQuestionarios/ListarQuestoes` e `ServicoGamificacao/ObterRanking`. Métodos protegidos não são chamados sem um token fornecido explicitamente na sessão.

## Reflection e segurança

A variável `HABILITAR_REFLECTION_GRPC` é aplicada pelo Compose local e tem valor padrão `true` apenas para desenvolvimento. A API rejeita essa configuração quando `AMBIENTE_EXECUCAO=producao`. Em produção, a variável deve permanecer ausente ou `false`; nesse cenário, o Postman deve usar uma definição Protobuf fornecida de forma controlada.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. O runner apenas chama métodos de leitura públicos e não altera a base principal.
