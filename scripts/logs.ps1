param(
    [ValidateSet('cache', 'api', 'gateway', 'frontend')]
    [string]$Servico = 'cache'
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.'
}

docker compose --env-file .env -f compose.yml --profile app logs -f --tail=100 $Servico
