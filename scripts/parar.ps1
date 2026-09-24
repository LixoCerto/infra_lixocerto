$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.'
}

$compose = @('--env-file', '.env', '-f', 'compose.yml', '--profile', 'app')
docker compose @compose stop
if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar a infraestrutura Docker.' }
