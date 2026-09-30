$ErrorActionPreference = 'Stop'

$diretorio = $PSScriptRoot
$arquivoRoot = Join-Path $diretorio '.env.minio-root'
$arquivoAplicacao = Join-Path $diretorio '.env.storage-app'
$existemRoot = Test-Path -LiteralPath $arquivoRoot
$existeAplicacao = Test-Path -LiteralPath $arquivoAplicacao

if ($existemRoot -and $existeAplicacao) {
  Write-Host 'Os arquivos locais do MinIO já existem; nenhum segredo foi sobrescrito.'
  return
}
if ($existemRoot -or $existeAplicacao) {
  throw 'Só um dos arquivos locais de configuração existe. Preserve-o e complete o outro manualmente; o script não sobrescreve credenciais parciais.'
}

function New-SecretHex([int]$bytes = 32) {
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $dados = New-Object byte[] $bytes
    $rng.GetBytes($dados)
    return [BitConverter]::ToString($dados).Replace('-', '').ToLowerInvariant()
  } finally {
    $rng.Dispose()
  }
}

$senhaRoot = New-SecretHex 32
$senhaAplicacao = New-SecretHex 32
$utf8SemBom = [System.Text.UTF8Encoding]::new($false)

$conteudoRoot = @"
MINIO_ROOT_USER=lcrroot
MINIO_ROOT_PASSWORD=$senhaRoot
"@
$conteudoAplicacao = @"
LCR_EVIDENCIAS_STORAGE=s3
LCR_EVIDENCIAS_S3_ENDPOINT=http://minio:9000
LCR_EVIDENCIAS_S3_BUCKET=lcr-evidencias-descartes
LCR_EVIDENCIAS_S3_REGION=us-east-1
LCR_EVIDENCIAS_S3_ACCESS_KEY=lcrapp
LCR_EVIDENCIAS_S3_SECRET_KEY=$senhaAplicacao
"@

[System.IO.File]::WriteAllText($arquivoRoot, $conteudoRoot.Trim() + [Environment]::NewLine, $utf8SemBom)
[System.IO.File]::WriteAllText($arquivoAplicacao, $conteudoAplicacao.Trim() + [Environment]::NewLine, $utf8SemBom)

Write-Host 'Configuração MinIO criada em arquivos locais ignorados pelo Git.'
Write-Host 'Proteja os dois arquivos; não os envie em capturas, commits ou mensagens.'
