param(
    [switch]$Aplicacao,
    [switch]$PrepararPostman,
    [switch]$SmokeTests,
    [switch]$SmokeAutenticado,
    [int]$TimeoutSmokeMilissegundos = 15000
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')

$compose = @(
    '--env-file', '..\api_lixocerto\.env',
    '--env-file', '..\frontend_lixocerto\.env',
    '-f', 'compose.yml'
)
if ($Aplicacao) {
    $compose += @('--profile', 'app')
    docker compose @compose up -d --build
} else {
    docker compose @compose up -d cache
}
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar a infraestrutura Docker.' }

function Get-ContainerState([string]$Container) { return ((docker inspect --format '{{.State.Status}}' $Container 2>$null | Out-String).Trim()) }
function Get-ContainerHealth([string]$Container) { return ((docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' $Container 2>$null | Out-String).Trim()) }
function Wait-ContainerState([string]$Container, [string]$Expected, [int]$TimeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if ((Get-ContainerState $Container) -eq $Expected) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Container $Container não atingiu o estado '$Expected'. Estado atual: $(Get-ContainerState $Container)"
}
function Wait-ContainerHealthy([string]$Container, [int]$TimeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if ((Get-ContainerHealth $Container) -eq 'healthy') { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Container $Container não ficou saudável. Health atual: $(Get-ContainerHealth $Container)"
}

if ($Aplicacao) {
    Wait-ContainerHealthy 'lcr-cache'
    Wait-ContainerState 'lcr-api' 'running'
    Wait-ContainerState 'lcr-gateway' 'running'
    Wait-ContainerHealthy 'lcr-frontend'
    Write-Host 'Redis, API, gateway e frontend estão em execução.' -ForegroundColor Green
}

if ($PrepararPostman) {
    & (Join-Path $PSScriptRoot 'preparar-postman.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar os contratos e arquivos do Postman.' }
}

if ($SmokeTests) {
    if (-not $Aplicacao) { throw 'Use -Aplicacao junto com -SmokeTests para garantir que a API esteja em execução.' }
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) { throw 'pnpm não encontrado. Instale Node.js com Corepack habilitado.' }
    if (-not (Test-Path -LiteralPath '..\api_lixocerto\node_modules')) {
        Push-Location '..\api_lixocerto'
        pnpm install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Falha ao instalar as dependências do runner gRPC.' }
        Pop-Location
    }
    Push-Location '..\api_lixocerto'
    pnpm smoke:grpc -- --timeout $TimeoutSmokeMilissegundos
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Smoke tests gRPC falharam. Consulte reports\grpc-smoke.json.' }
    pnpm smoke:grpc:reflection
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Server reflection gRPC não respondeu. Verifique HABILITAR_REFLECTION_GRPC e os logs da API.' }
    if ($SmokeAutenticado) {
        pnpm smoke:grpc:auth
        if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'Smoke autenticado falhou. Defina GRPC_SMOKE_EMAIL e GRPC_SMOKE_PASSWORD e confirme que a conta existe.' }
    }
    Pop-Location
}

docker compose @compose ps
