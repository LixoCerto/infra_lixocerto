$ErrorActionPreference = 'Stop'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$apiRoot = (Resolve-Path (Join-Path $infraRoot '..\api_lixocerto')).Path
$frontendRoot = (Resolve-Path (Join-Path $infraRoot '..\frontend_lixocerto')).Path
$apiEnvPath = Join-Path $apiRoot '.env'
$frontendEnvPath = Join-Path $frontendRoot '.env'

if (-not (Test-Path -LiteralPath $apiEnvPath)) {
    throw "Arquivo da API não encontrado: $apiEnvPath. Crie-o a partir de .env.exemplo."
}
if (-not (Test-Path -LiteralPath $frontendEnvPath)) {
    throw "Arquivo do frontend não encontrado: $frontendEnvPath. Crie-o a partir de .env.exemplo."
}

function Get-EnvValue([string]$Path, [string]$Name) {
    $linha = Get-Content -LiteralPath $Path | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $linha) { return $null }
    return ($linha -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

$obrigatoriasApi = @(
    'BANCO_DADOS_HOST', 'BANCO_DADOS_PORTA', 'BANCO_DADOS_USUARIO',
    'BANCO_DADOS_SENHA', 'BANCO_DADOS_NOME', 'REDIS_PASSWORD',
    'SEGREDO_JWT', 'SEGREDO_HASH_PARTICIPANTE', 'SEGREDO_CODIGO_EMAIL'
)
foreach ($nome in $obrigatoriasApi) {
    if ([string]::IsNullOrWhiteSpace((Get-EnvValue $apiEnvPath $nome))) {
        throw "$nome não está configurada em $apiEnvPath."
    }
}
if ([string]::IsNullOrWhiteSpace((Get-EnvValue $frontendEnvPath 'VITE_API_BASE_URL'))) {
    throw 'VITE_API_BASE_URL não está configurada no .env do frontend.'
}

Write-Host 'Ambientes da API e do frontend encontrados e validados.' -ForegroundColor Green
Write-Host "API: $apiEnvPath"
Write-Host "Frontend: $frontendEnvPath"
Write-Host 'A infraestrutura não possui nem cria um .env próprio.' -ForegroundColor Yellow
