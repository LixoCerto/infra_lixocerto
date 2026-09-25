param(
    [switch]$Confirmar
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not $Confirmar) {
    throw 'Operação protegida. Para remover somente o volume local do Keycloak, execute: .\scripts\resetar-keycloak-local.ps1 -Confirmar'
}

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute .\scripts\configurar-desenvolvimento.ps1 primeiro.'
}

function Get-EnvValue([string]$Name, [string]$DefaultValue) {
    $linha = Get-Content -LiteralPath '.env' | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $linha) { return $DefaultValue }
    return ($linha -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

$compose = @('--env-file', '.env', '-f', 'compose.yml', '--profile', 'app')
$volume = Get-EnvValue 'KEYCLOAK_VOLUME_NAME' 'lcr-keycloak-data'

Write-Host "Parando somente o serviço Keycloak..." -ForegroundColor Yellow
docker compose @compose stop keycloak
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível parar o serviço Keycloak.' }

docker compose @compose rm -sf keycloak
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível remover o container Keycloak.' }

$existe = docker volume inspect $volume 2>$null
if ($LASTEXITCODE -eq 0 -and $existe) {
    docker volume rm $volume | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível remover o volume local $volume." }
    Write-Host "Volume local removido: $volume" -ForegroundColor Green
} else {
    Write-Host "Volume local não encontrado: $volume" -ForegroundColor DarkYellow
}

Write-Host 'Nenhum volume Redis, container API ou PostgreSQL externo foi alterado.' -ForegroundColor Green
Write-Host 'Agora execute: .\scripts\iniciar.ps1 -Aplicacao -PrepararPostman -SmokeTests' -ForegroundColor Cyan
