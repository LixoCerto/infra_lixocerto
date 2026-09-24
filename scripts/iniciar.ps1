param(
    [switch]$Aplicacao
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.exemplo' -Destination '.env'
    Write-Host 'Arquivo .env criado. Revise REDIS_PASSWORD antes de continuar.' -ForegroundColor Yellow
}

$compose = @('--env-file', '.env', '-f', 'compose.yml')
if ($Aplicacao) {
    $compose += @('--profile', 'app')
    docker compose @compose up -d --build
} else {
    docker compose @compose up -d cache
}

if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar a infraestrutura Docker.' }
docker compose @compose ps
