$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')
$compose = @('-f', 'compose.yml', '--profile', 'app')
docker compose @compose ps
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar o Compose.' }

$apiEnv = (Resolve-Path '..\api_lixocerto\.env').Path
$senha = (Get-Content -LiteralPath $apiEnv | Where-Object { $_ -match '^REDIS_PASSWORD=' } | Select-Object -First 1) -replace '^REDIS_PASSWORD=', ''
if ([string]::IsNullOrWhiteSpace($senha)) { throw 'REDIS_PASSWORD não configurada na API.' }

$env:REDIS_PASSWORD = $senha
docker compose @compose exec -T cache redis-cli -a $env:REDIS_PASSWORD ping
if ($LASTEXITCODE -ne 0) { throw 'Healthcheck Redis falhou.' }
Remove-Item Env:\REDIS_PASSWORD -ErrorAction SilentlyContinue

Write-Host 'Infraestrutura Lixo Certo: Redis, API gRPC, gateway e frontend verificados.' -ForegroundColor Green
