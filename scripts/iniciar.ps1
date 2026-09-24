$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.exemplo' -Destination '.env'
    Write-Host 'Arquivo .env criado a partir de .env.exemplo. Revise REDIS_PASSWORD antes de continuar.' -ForegroundColor Yellow
}

$compose = @('--env-file', '.env', '-f', 'compose.yml')
docker compose @compose up -d
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar a infraestrutura Docker.' }

docker compose @compose ps
