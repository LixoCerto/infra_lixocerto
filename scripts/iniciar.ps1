param(
    [switch]$Aplicacao,
    [switch]$PrepararPostman,
    [switch]$SmokeTests
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.exemplo' -Destination '.env'
}

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')

$compose = @('--env-file', '.env', '-f', 'compose.yml')
if ($Aplicacao) {
    $compose += @('--profile', 'app')
    docker compose @compose up -d --build
} else {
    docker compose @compose up -d cache
}

if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar a infraestrutura Docker.' }

function Get-ContainerState([string]$Container) {
    return ((docker inspect --format '{{.State.Status}}' $Container 2>$null | Out-String).Trim())
}

function Get-ContainerHealth([string]$Container) {
    return ((docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' $Container 2>$null | Out-String).Trim())
}

function Wait-ContainerState([string]$Container, [string]$Expected, [int]$TimeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $state = Get-ContainerState $Container
        if ($state -eq $Expected) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Container $Container não atingiu o estado '$Expected'. Estado atual: $(Get-ContainerState $Container)"
}

function Wait-ContainerHealthy([string]$Container, [int]$TimeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $health = Get-ContainerHealth $Container
        if ($health -eq 'healthy') { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Container $Container não ficou saudável. Health atual: $(Get-ContainerHealth $Container)"
}

function Wait-HttpEndpoint([string]$Url, [int]$TimeoutSeconds = 180) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $resposta = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
            if ($resposta.StatusCode -ge 200 -and $resposta.StatusCode -lt 500) { return }
        } catch {
            Start-Sleep -Seconds 3
        }
    } while ((Get-Date) -lt $deadline)
    throw "Endpoint não ficou disponível: $Url"
}

function Get-EnvValue([string]$Name, [string]$DefaultValue) {
    $line = Get-Content -LiteralPath '.env' | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) { return $DefaultValue }
    return ($line -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

if ($Aplicacao) {
    Wait-ContainerHealthy 'lcr-cache'
    Wait-ContainerState 'lcr-keycloak' 'running'
    Wait-HttpEndpoint "http://127.0.0.1:$(Get-EnvValue 'KEYCLOAK_PORT' '8081')/realms/lixo-certo/.well-known/openid-configuration"
    Wait-ContainerState 'lcr-api' 'running'
    Wait-ContainerState 'lcr-gateway' 'running'
    Wait-ContainerHealthy 'lcr-frontend'
    Write-Host 'Redis, Keycloak, API, gateway e frontend estão em execução.' -ForegroundColor Green
}

if ($PrepararPostman) {
    & (Join-Path $PSScriptRoot 'preparar-postman.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar os contratos e arquivos do Postman.' }
}

if ($SmokeTests) {
    if (-not $Aplicacao) {
        throw 'Use -Aplicacao junto com -SmokeTests para garantir que a API esteja em execução.'
    }
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        throw 'pnpm não encontrado. Instale Node.js com Corepack habilitado.'
    }
    if (-not (Test-Path -LiteralPath 'node_modules')) {
        pnpm install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependências do runner gRPC.' }
    }
    pnpm smoke:grpc
    if ($LASTEXITCODE -ne 0) { throw 'Smoke tests gRPC falharam. Consulte reports\grpc-smoke.json.' }
    pnpm smoke:grpc:reflection
    if ($LASTEXITCODE -ne 0) { throw 'Server reflection gRPC não respondeu. Verifique HABILITAR_REFLECTION_GRPC e os logs da API.' }
    pnpm smoke:grpc:auth
    if ($LASTEXITCODE -ne 0) { throw 'Smoke autenticado falhou. Verifique o realm Keycloak, o usuário administrador e as permissões LCR.' }
}

docker compose @compose ps
