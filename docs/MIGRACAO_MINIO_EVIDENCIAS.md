# MinIO S3 local para evidências de descarte

## Decisão de armazenamento

A API passa a usar uma imagem local própria do MinIO Community, compilada do [código-fonte oficial](https://github.com/minio/minio/tree/RELEASE.2025-10-15T17-29-55Z) no commit `9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a` (`RELEASE.2025-10-15T17-29-55Z`). O cliente `mc` também é compilado localmente do [código-fonte oficial](https://github.com/minio/mc/tree/RELEASE.2025-08-13T08-35-41Z) no commit `7394ce0dd2a80935aded936b09fa12cbb3cb8096` (`RELEASE.2025-08-13T08-35-41Z`). Os Dockerfiles validam cada SHA durante o build; os nomes de imagem locais não tentam fazer pull de `minio/minio` nem `minio/mc`. Isso contorna a indisponibilidade do registry, mas **não restaura manutenção upstream**. MinIO Community e `mc` estão sob AGPLv3; o upstream está arquivado/sem manutenção e sem atualizações oficiais. Não é AIStor e não requer sua licença; compile/use sob sua própria avaliação de risco e obrigações da licença.

MinIO não é exposto à rede pública: a API usa `http://minio:9000` na rede Docker e as portas para a máquina local ficam limitadas a `127.0.0.1` (`9000` S3 e `9001` console). O bucket `lcr-evidencias-descartes` é privado. O build baixa as bases Debian/Go e o código upstream via GitHub; não baixa MinIO de um registry.

O usuário root do MinIO fica em `.env.minio-root`; a API recebe somente uma chave de serviço separada, com permissões restritas ao bucket. `PrepararMinio.ps1` gera os segredos localmente, sem imprimi-los. Esses arquivos são ignorados pelo Git. Não os envie em mensagens, anexos ou capturas, e não use o usuário root da console na API.

As versões do servidor e do cliente são fixadas por release e SHA de commit. O `pull_policy: never` impede que Compose tente baixar os nomes locais das imagens; a etapa de build explícita abaixo é obrigatória. A imagem Go e a base Debian continuam identificadas por tags de versão upstream, e podem receber atualizações de base quando reconstruídas com `--pull`.

## O que é transferido

A rotina temporária `evidencia-migration` lê o volume antigo `lcr-descartes-evidencias` somente como leitura e consulta a tabela `lcr_registros_descartes` para selecionar evidências ainda válidas. Para cada chave ativa, exige o arquivo correspondente, compara o SHA-256 e o tamanho contra os metadados do banco quando existentes, copia para `<uuid>.webp` no bucket e baixa o objeto de volta para comparar o SHA-256. Se existir divergência, arquivo ausente, chave inválida ou falha de acesso, encerra com erro antes de permitir a troca da API.

A cópia é idempotente: repetir a operação verifica um objeto MinIO já existente; não o sobrescreve se o conteúdo for diferente. Ela **não altera nem apaga o volume antigo** e não altera o banco. Fotos sem referência ativa permanecem exclusivamente no volume legado, que também continua preservado.

## Migração no notebook Windows (PowerShell)

Faça esta etapa em `G:\LixoCerto` após atualizar os três repositórios. Mantenha os arquivos locais `.env` existentes; não os mostre nem os substitua. Não use `docker compose down -v`.

### 1. Gerar segredos locais e validar os pré-requisitos

```powershell
Set-Location G:\LixoCerto\infra_lixocerto

# Gera .env.minio-root e .env.storage-app somente se ainda não existirem.
.\PrepararMinio.ps1

test-path .env.minio-root
test-path .env.storage-app
docker volume inspect lcr-descartes-evidencias
```

Se o script disser que os arquivos já existem, ele não os sobrescreve. Se só um existir, interrompa e preserve-o; complete a configuração com segurança em vez de recriar segredos. O último comando confirma que o volume local antigo está disponível; se falhar, pare e não inicie a API nova.

### 2. Backup prévio e parada para consistência

Antes de migrar, faça o dump do PostgreSQL conforme `OPERACAO_PRIVACIDADE_E_BACKUP.md`. Como medida adicional, arquive o volume antigo depois de parar a API. Use uma pasta de backup protegida fora do Git:

```powershell
$ErrorActionPreference = 'Stop'
$backupDir = Join-Path $env:USERPROFILE 'LixoCertoBackups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$arquivoLegado = Join-Path $backupDir ("lcr-evidencias-legado-{0}.tar.gz" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$bind = "type=bind,source=$($backupDir.Replace([char]92, [char]47)),target=/backup"

$apiEstavaAtiva = [bool](docker compose -f compose.yml --profile app ps -q --status running api)
$backupValidado = $false
docker compose -f compose.yml --profile app stop api
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível parar a API; não prossiga com a migração.' }
try {
  docker run --rm `
    --mount 'type=volume,source=lcr-descartes-evidencias,target=/origem,readonly' `
    --mount $bind `
    alpine:3.20 sh -c "tar -czf /backup/$([IO.Path]::GetFileName($arquivoLegado)) -C /origem ."
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao arquivar o volume legado.' }
  docker run --rm --mount $bind alpine:3.20 tar -tzf "/backup/$([IO.Path]::GetFileName($arquivoLegado))" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'O arquivo do volume legado não passou na verificação.' }
  Get-Item $arquivoLegado | Select-Object FullName, Length, LastWriteTime
  $backupValidado = $true
} finally {
  # Reinicia a versão antiga em caso de falha. Em sucesso, mantenha-a parada até a troca descrita abaixo.
  if ($apiEstavaAtiva -and -not $backupValidado) {
    docker compose -f compose.yml --profile app start api
  }
}
```

**Importante:** se o dump do banco ou o arquivo legado não puder ser validado, pare aqui. O volume original é uma cópia de segurança operacional; a rotina de migração não o remove.

### 3. Construir localmente MinIO e `mc`, depois inicializar o serviço, sem iniciar a API

```powershell
# Compila MinIO Community e o cliente mc a partir dos commits oficiais fixados.
# O build pode demorar; exige acesso ao Docker Hub para bases Go/Debian e ao GitHub para o código.
docker compose -f compose.yml --profile app build --pull --no-cache minio minio-bootstrap

# Inicia MinIO, prepara permissões do volume novo e executa o bootstrap do bucket/chave.
docker compose -f compose.yml --profile app up -d minio minio-bootstrap
docker compose -f compose.yml --profile app ps minio minio-data-init minio-bootstrap
```

O Compose usa imagens locais `lixocerto-minio-community` e `lixocerto-minio-client`; não deve tentar baixar `minio/minio` ou `minio/mc`. O bootstrap aguarda o serviço, cria o bucket privado e provisiona a identidade limitada da API. Se a compilação ou o bootstrap terminar com erro, não inicie a API; confira os logs sem copiar variáveis de ambiente ou credenciais.

### 4. Validar referências e copiar, primeiro com dry-run

```powershell
# Não altera objetos. Confere conexão, referências ativas, existência dos arquivos locais,
# chaves UUID, tamanhos e hashes registrados no banco.
docker compose -f compose.yml --profile app --profile maintenance run --rm evidencia-migration --dry-run

# Só execute se o dry-run terminar com exit code 0.
docker compose -f compose.yml --profile app --profile maintenance run --rm evidencia-migration
```

O resultado informa apenas contagens e bytes; não lista nomes de participantes nem conteúdo das fotos. `migracao_verificada` significa que todos os objetos ativos referenciados foram encontrados, validados contra os metadados quando disponíveis, gravados ou conferidos no MinIO e lidos de volta com SHA-256 igual. Se houver erro, mantenha a API parada e o volume legado intacto; resolva a causa antes de tentar novamente.

### 5. Trocar a API e verificar

Depois da migração bem-sucedida, recrie somente a API, que é o componente alterado. O frontend permanece em execução e não precisa ser reconstruído nesta mudança. O volume MinIO fica montado em `lcr-minio-data`:

```powershell
docker compose -f compose.yml --profile app up -d --no-deps --force-recreate api
Start-Sleep -Seconds 20
docker compose -f compose.yml --profile app ps
curl.exe -I http://localhost:3000/
```

Aceite operacional: `lcr-api` e `lcr-frontend` saudáveis; frontend retorna `200 OK`; acesso a evidências ainda válidas funciona somente pelo RPC autenticado da aplicação. O console S3 fica em `http://localhost:9001` para administração local. Não habilite acesso anônimo ao bucket.

## Rollback sem apagar dados

Se a validação da cópia falhar, não recrie a API com o driver S3. A rotina mantém o volume `lcr-descartes-evidencias` e não altera o banco. Se a troca já ocorreu e houver falha na leitura, pare a API nova e restaure o Compose/API da versão anterior para voltar temporariamente ao volume local. Não remova o volume legado, o volume MinIO, nem execute `docker volume prune`/`docker compose down -v` como tentativa de correção.

Não existe limpeza automática do volume legado nesta mudança. A exclusão dele é deliberadamente manual e só deve ocorrer após confirmação independente de backup e validação integral do uso do MinIO.

## Backup e recuperação após a migração

Após a troca, o armazenamento ativo é o volume Docker `lcr-minio-data`; o bucket segue privado e as fotos não são guardadas no banco. Para um backup pareado, pare temporariamente API e MinIO e arquive o volume MinIO na mesma janela do dump do PostgreSQL, conforme a seção atualizada em `api_lixocerto/docs/OPERACAO_PRIVACIDADE_E_BACKUP.md`. Faça o teste de restauração em volume descartável e nunca sobre o original. Mantenha o volume legado isolado até a decisão operacional de removê-lo.
