param(
    [string]$HostGrpc = '127.0.0.1:50051',
    [int]$TimeoutMilissegundos = 5000
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    throw 'pnpm não encontrado. Instale Node.js com Corepack habilitado.'
}

if (-not (Test-Path -LiteralPath 'node_modules')) {
    pnpm install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependências do runner gRPC.' }
}

pnpm smoke:grpc -- --host $HostGrpc --timeout $TimeoutMilissegundos
if ($LASTEXITCODE -ne 0) {
    throw 'Smoke tests gRPC falharam. Consulte reports\grpc-smoke.json.'
}

pnpm smoke:grpc:reflection -- $HostGrpc
if ($LASTEXITCODE -ne 0) {
    throw 'Server reflection gRPC não respondeu. Verifique HABILITAR_REFLECTION_GRPC e os logs da API.'
}
