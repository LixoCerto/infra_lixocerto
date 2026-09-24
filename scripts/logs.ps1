$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.'
}

docker compose --env-file .env -f compose.yml logs -f --tail=100 cache
