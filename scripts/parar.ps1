$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')
$compose = @('--env-file', '..\api_lixocerto\.env', '--env-file', '..\frontend_lixocerto\.env', '-f', 'compose.yml', '--profile', 'app')
docker compose @compose stop
if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar a infraestrutura Docker.' }
