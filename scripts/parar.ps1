$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')
docker compose -f compose.yml --profile app stop
if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar a infraestrutura Docker.' }
