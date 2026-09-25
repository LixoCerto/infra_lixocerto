# Automação local — Lixo Certo

## Objetivo

O projeto fornece um fluxo híbrido e reproduzível. O Docker sobe Redis, Mailpit, Keycloak, API, gateway e frontend; os runners gRPC verificam métodos públicos e protegidos; o script do Postman prepara contratos, definição raiz, ambiente e catálogo para que o cliente Postman crie requisições gRPC nativas.

A distinção é importante: o Postman não trata um item Collection JSON v2.1 com `method: POST` e URL `grpc://` como uma requisição gRPC nativa. Por isso o fluxo não copia mais a coleção JSON legada e não promete uma importação que o cliente não suporta.

## Execução completa no Windows

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Esse comando cria ou completa o `.env` de infraestrutura sem alterar o arquivo privado da API nem o PostgreSQL externo, constrói os seis serviços Docker, aguarda Mailpit e o realm Keycloak, habilita server reflection apenas no ambiente local, prepara os contratos no diretório do Postman e executa os smoke tests gRPC públicos, reflection e autenticados. O smoke público usa timeout padrão de 15 segundos para acomodar a primeira consulta ao PostgreSQL externo. O relatório público é gravado em `reports\grpc-smoke.json`.

O realm local possui os clientes `lixo-certo-frontend` e `lixo-certo-postman`, além dos papéis `usuario`, `pesquisador`, `revisor` e `administrador`. Os usuários comuns e administrativos são parametrizados no `.env` e o arquivo do realm não contém senhas reais.

## Ciclo de conta no frontend

A página `http://localhost:3000/login` direciona cada ação para o Keycloak, preservando Authorization Code + PKCE. Ela disponibiliza login, criação de conta, recuperação de senha, atualização de senha após autenticação e Google quando o provedor social estiver configurado. Senhas nunca são coletadas pelo React.

O realm exige confirmação de e-mail para contas novas e permite recuperação de senha. No desenvolvimento, as mensagens são capturadas no Mailpit:

```text
http://localhost:8025
```

Mailpit não entrega e-mails fora do notebook. Abra a mensagem recebida, use o link de confirmação ou redefinição e conclua o fluxo no Keycloak; o navegador retornará a `/callback` quando aplicável.

### Google OAuth (opcional)

O botão Google permanece desabilitado até que exista um OAuth Client de Google real. No Google Cloud, crie um cliente **Web application** e autorize exatamente a URI local do broker Keycloak:

```text
http://localhost:8081/realms/lixo-certo/broker/google/endpoint
```

Depois, sem colocar o segredo no terminal, Git ou `.env`, informe o Client Secret como `SecureString`:

```powershell
$segredoGoogle = Read-Host 'Client Secret Google' -AsSecureString
.\scripts\configurar-google-keycloak.ps1 -ClientId 'SEU_CLIENT_ID.apps.googleusercontent.com' -ClientSecret $segredoGoogle
```

O script cria ou atualiza o provider `google` pela API administrativa local do Keycloak e reconstrói somente o frontend com a flag pública de habilitação. O Client Secret não é gravado.

Se `resetar-keycloak-local.ps1 -Confirmar` for executado depois disso, o provider Google é removido junto com o volume local e a flag pública é desabilitada automaticamente. Execute novamente o configurador com o Client Secret para reativá-lo.

No desenvolvimento, se o provedor não incluir `email` no access token, a API usa o fallback determinístico `preferred_username@lixo-certo.local` para atender ao campo obrigatório do schema LCR. Esse fallback depende de `AMBIENTE_EXECUCAO=desenvolvimento` e não é permitido em produção.

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

Se o arquivo `keycloak\lixo-certo-realm.json` for alterado, o Keycloak já existente não o reimporta automaticamente. Nesse caso, recrie somente o volume local do Keycloak — nunca o Redis e nunca o PostgreSQL — com confirmação explícita:

```powershell
.\scripts\resetar-keycloak-local.ps1 -Confirmar
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Os testes cobrem `ServicoSaude/Verificar`, `ServicoMateriais/ListarMateriais`, `ServicoPontosColeta/ListarPontosColeta`, `ServicoQuestionarios/ListarQuestoes` e `ServicoGamificacao/ObterRanking`. O `smoke:grpc:auth` obtém um token temporário do cliente local `lixo-certo-postman` usando o usuário administrador parametrizado no `.env` e valida `ServicoAutenticacao/ObterIdentidadeAtual` e `ServicoAdministracao/ObterResumoAdministrativo`. O token nunca é impresso.

Para obter um token no ambiente local do Postman, execute:

```powershell
.\scripts\obter-token-postman.ps1
```

Para usar o usuário administrador:

```powershell
.\scripts\obter-token-postman.ps1 -Administrador
```

O script grava o `access_token` apenas em `%USERPROFILE%\Postman\files\lixo-certo\Lixo-Certo-API.postman_environment.json`. As requisições protegidas devem enviar `authorization: Bearer {{jwt_token}}` na aba **Metadata**.

## Reflection e segurança

A variável `HABILITAR_REFLECTION_GRPC` é aplicada pelo Compose local e tem valor padrão `true` apenas para desenvolvimento. A API rejeita essa configuração quando `AMBIENTE_EXECUCAO=producao`. Em produção, a variável deve permanecer ausente ou `false`; nesse cenário, o Postman deve usar uma definição Protobuf fornecida de forma controlada.

O PostgreSQL externo não é criado, destruído ou migrado pelo Compose. O smoke autenticado executa somente uma consulta de identidade e uma leitura administrativa; a sincronização do usuário pode criar ou atualizar o registro correspondente ao usuário de desenvolvimento no banco LCR, mas não remove tabelas nem executa migrações.
