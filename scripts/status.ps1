$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.'
}

$compose = @('--env-file', '.env', '-f', 'compose.yml', '--profile', 'app')
docker compose @compose ps
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível consultar o Compose.' }

$senha = (Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^REDIS_PASSWORD=' } | Select-Object -First 1) -replace '^REDIS_PASSWORD=', ''
if ([string]::IsNullOrWhiteSpace($senha)) { throw 'REDIS_PASSWORD não configurada.' }

$env:REDIS_PASSWORD = $senha
docker compose @compose exec -T cache redis-cli -a $env:REDIS_PASSWORD ping
if ($LASTEXITCODE -ne 0) { throw 'Healthcheck Redis falhou.' }
Remove-Item Env:\REDIS_PASSWORD -ErrorAction SilentlyContinue

$portaKeycloak = (Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^KEYCLOAK_PORT=' } | Select-Object -First 1) -replace '^KEYCLOAK_PORT=', ''
if ([string]::IsNullOrWhiteSpace($portaKeycloak)) { $portaKeycloak = '8081' }
try {
    Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$portaKeycloak/realms/lixo-certo/.well-known/openid-configuration" -TimeoutSec 5 | Out-Null
    Write-Host 'Keycloak realm lixo-certo: disponível.' -ForegroundColor Green
} catch {
    throw 'Keycloak realm lixo-certo não está disponível.'
}

$portaMailpit = (Get-Content -LiteralPath '.env' | Where-Object { $_ -match '^MAILPIT_WEB_PORT=' } | Select-Object -First 1) -replace '^MAILPIT_WEB_PORT=', ''
if ([string]::IsNullOrWhiteSpace($portaMailpit)) { $portaMailpit = '8025' }
try {
    Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$portaMailpit/" -TimeoutSec 5 | Out-Null
    Write-Host 'Mailpit local: disponível.' -ForegroundColor Green
} catch {
    throw 'Mailpit local não está disponível.'
}
