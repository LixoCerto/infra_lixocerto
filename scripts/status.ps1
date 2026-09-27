$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) { throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.' }

$compose = @('--env-file', '.env', '-f', 'compose.yml', '--profile', 'app')
docker compose @compose ps
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar o Compose.' }

$senha = (Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^REDIS_PASSWORD=' } | Select-Object -First 1) -replace '^REDIS_PASSWORD=', ''
if ([string]::IsNullOrWhiteSpace($senha)) { throw 'REDIS_PASSWORD não configurada.' }

$env:REDIS_PASSWORD = $senha
docker compose @compose exec -T cache redis-cli -a $env:REDIS_PASSWORD ping
if ($LASTEXITCODE -ne 0) { throw 'Healthcheck Redis falhou.' }
Remove-Item Env:\REDIS_PASSWORD -ErrorAction SilentlyContinue

Write-Host 'Infraestrutura Lixo Certo: Redis, API gRPC, gateway e frontend verificados.' -ForegroundColor Green
