# Automação local — Lixo Certo

## Objetivo

O projeto fornece um fluxo reproduzível. O Docker sobe Redis, API, gateway e frontend; os runners gRPC verificam métodos públicos; o Postman recebe os contratos para salvar requisições gRPC nativas.

A API usa autenticação própria: cadastro, login, JWT de acesso, refresh token rotacionado, logout e autorização por papéis/permissões. Keycloak, OIDC e Mailpit não são necessários.

## Execução completa no Windows

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Esse comando cria ou completa o `.env` da infraestrutura sem alterar o `.env` privado da API nem o PostgreSQL externo, constrói os quatro serviços Docker, aguarda healthchecks, prepara os contratos no diretório do Postman e executa smoke público e reflection.

O configurador gera `SEGREDO_JWT` e `REDIS_PASSWORD` localmente quando ainda são placeholders. Os valores não são impressos.

## Banco externo

O Compose não cria, destrói ou migra o PostgreSQL externo. A migration da autenticação própria é `022_adicionar_lcr_hash_senha_usuario.cjs` e deve ser aplicada conscientemente no repositório da API:

```powershell
cd G:\LixoCerto\api_lixocerto
pnpm migrar
pnpm semear
```

Não execute esses comandos apontando para outro banco sem conferir `BANCO_DADOS_HOST/PORTA/USUARIO/SENHA/NOME`. Não faça rollback ou `down -v` no banco externo.

## Ciclo de conta local

A API expõe:

- `ServicoAutenticacao/CadastrarUsuario`;
- `ServicoAutenticacao/Entrar`;
- `ServicoAutenticacao/RenovarToken`;
- `ServicoAutenticacao/Sair`;
- `ServicoAutenticacao/ObterIdentidadeAtual`.

Para preencher o ambiente do Postman:

```powershell
.\scripts\obter-token-postman.ps1 -Email 'usuario@exemplo.test'
```

O script solicita a senha como `SecureString`, executa `Entrar` em `grpc://127.0.0.1:50051` e grava `jwt_token` e `token_atualizacao` somente no arquivo local do Postman. Ele não imprime os tokens.

Para chamadas protegidas, configure:

```text
authorization: Bearer {{jwt_token}}
```

## Smoke autenticado opcional

O fluxo padrão não exige credenciais. Para testar autenticação explicitamente, defina variáveis somente no processo atual do PowerShell:

```powershell
$env:GRPC_SMOKE_EMAIL = 'usuario@exemplo.test'
$env:GRPC_SMOKE_PASSWORD = 'senha somente nesta sessão'
.\scripts\testar.ps1 -SmokeAutenticado
Remove-Item Env:GRPC_SMOKE_EMAIL, Env:GRPC_SMOKE_PASSWORD -ErrorAction SilentlyContinue
```

Nunca grave essas variáveis no Git ou em `.env` versionado.

## Arquivos preparados para o Postman

O diretório padrão é `%USERPROFILE%\Postman\files\lixo-certo` e contém contratos, definição raiz, ambiente, catálogo de 26 métodos e README. O catálogo não é uma Collection JSON importável: ele evita que uma requisição HTTP `POST` com URL `grpc://` seja confundida com gRPC nativo.

Após iniciar a aplicação, abra o Postman Desktop, selecione o ambiente, use **New > gRPC**, `grpc://{{grpc_host}}`, escolha o método e salve com **Save As**. O botão de execução deve aparecer como **Invoke**.

## Validação esperada

```text
Smoke gRPC: 5/5 aprovados em 127.0.0.1:50051
Server reflection gRPC: 13 serviços descobertos em 127.0.0.1:50051
```

A variável `HABILITAR_REFLECTION_GRPC` deve ficar habilitada apenas no desenvolvimento local. A API rejeita reflection em produção.
