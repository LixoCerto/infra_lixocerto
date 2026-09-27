# Automação local — Lixo Certo

## Objetivo

O projeto fornece um fluxo híbrido e reproduzível. O Docker sobe Redis, API, gateway e frontend; os runners gRPC verificam métodos públicos; o Postman prepara os contratos para salvar requisições gRPC nativas.

A API usa **autenticação própria**: cadastro, login, JWT de acesso, refresh token rotacionado, logout e autorização por papéis/permissões. Keycloak/OIDC não é necessário para a API.

## Execução completa no Windows

No PowerShell, a partir de `G:\LixoCerto\infra_lixocerto`:

```powershell
.\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests
```

Esse comando cria ou completa o `.env` de infraestrutura sem alterar o arquivo privado da API nem o PostgreSQL externo, constrói os serviços Docker, aguarda Redis/API/gateway/frontend, prepara os contratos no diretório do Postman e executa os smoke tests públicos e de reflection.

O configurador gera `SEGREDO_JWT` localmente quando o valor ainda é um placeholder. O segredo não é impresso. Variáveis OIDC/Keycloak que ainda aparecem no Compose são mantidas somente para o frontend legado enquanto ele não for migrado para o login gRPC.

## Banco externo

O Compose não cria, destrói ou migra o PostgreSQL externo. A migration da autenticação própria é `022_adicionar_lcr_hash_senha_usuario.cjs` e deve ser aplicada conscientemente no repositório da API:

```powershell
cd G:\LixoCerto\api_lixocerto
pnpm migrar
pnpm semear
```

Não execute esses comandos apontando para outro banco sem conferir `URL_BANCO_DADOS`. Não faça rollback ou `down -v` no banco externo.

## Ciclo de conta local

A API expõe estes RPCs:

- `ServicoAutenticacao/CadastrarUsuario`;
- `ServicoAutenticacao/Entrar`;
- `ServicoAutenticacao/RenovarToken`;
- `ServicoAutenticacao/Sair`;
- `ServicoAutenticacao/ObterIdentidadeAtual`.

Para preencher o ambiente do Postman depois que uma conta existir:

```powershell
.\scripts\obter-token-postman.ps1 -Email 'usuario@exemplo.test'
```

O script solicita a senha como `SecureString`, executa `Entrar` pelo gRPC em `grpc://127.0.0.1:50051` e grava `jwt_token` e `token_atualizacao` somente no arquivo local do Postman. Ele não imprime os tokens.

Para chamadas protegidas, configure:

```text
authorization: Bearer {{jwt_token}}
```

## Smoke autenticado opcional

O fluxo padrão não exige credenciais e não altera o banco. Para testar autenticação explicitamente, defina as variáveis somente no processo atual do PowerShell:

```powershell
$env:GRPC_SMOKE_EMAIL = 'usuario@exemplo.test'
$env:GRPC_SMOKE_PASSWORD = 'senha somente nesta sessão'
```

Como o runner Node precisa do valor textual em memória, use uma sessão controlada, não registre o comando no histórico e remova as variáveis depois; nunca as grave no Git. Para uso normal do Postman, prefira `obter-token-postman.ps1`, que solicita a senha sem eco.

```powershell
.\scripts\testar.ps1 -SmokeAutenticado
Remove-Item Env:GRPC_SMOKE_EMAIL, Env:GRPC_SMOKE_PASSWORD -ErrorAction SilentlyContinue
```

O smoke autenticado valida `Entrar`, `ObterIdentidadeAtual` e `ObterResumoAdministrativo`.

## Arquivos preparados para o Postman

O diretório padrão é `%USERPROFILE%\Postman\files\lixo-certo` e contém os contratos em `contratos\lixo_certo\v1\`, a definição raiz `Lixo-Certo-API.postman.proto`, o ambiente `Lixo-Certo-API.postman_environment.json`, o catálogo `Lixo-Certo-API.grpc.manifest.json` e uma cópia do README.

O catálogo possui os 26 métodos, mensagens e metadados, mas está marcado explicitamente como não importável como Collection JSON. Se uma execução anterior deixou `Lixo-Certo-API.postman_collection.json` nesse diretório, o script o remove para impedir que um item HTTP `POST` seja confundido com gRPC nativo.

## Salvamento nativo no Postman

Após iniciar a aplicação, abra o Postman Desktop e selecione o ambiente `Lixo Certo — API local — gRPC`. Crie uma requisição por **New > gRPC**, use `grpc://{{grpc_host}}` e aguarde a lista de métodos carregada por server reflection. Se reflection não estiver disponível, importe `Lixo-Certo-API.postman.proto` pela aba **Service definition**.

Selecione cada método, use a mensagem e os metadados do catálogo e escolha **Save As** para a coleção `Lixo Certo — API gRPC — Nativa`. O botão de execução de uma chamada unary deve aparecer como **Invoke**.

## Execução por etapas

```powershell
.\scripts\iniciar.ps1 -Aplicacao
.\scripts\preparar-postman.ps1
.\scripts\testar.ps1
```

A validação pública esperada é:

```text
Smoke gRPC: 5/5 aprovados em 127.0.0.1:50051
Server reflection gRPC: 13 serviços descobertos em 127.0.0.1:50051
```

A variável `HABILITAR_REFLECTION_GRPC` deve ficar habilitada apenas no desenvolvimento local. A API rejeita reflection em produção.
