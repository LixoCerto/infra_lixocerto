param(
    [string]$DiretorioPostman = (Join-Path $HOME 'Postman\files\lixo-certo')
)

$ErrorActionPreference = 'Stop'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envPath = Join-Path $infraRoot '.env'

function Get-DotEnvValue([string]$Name, [string]$DefaultValue) {
    if (-not (Test-Path -LiteralPath $envPath)) { return $DefaultValue }
    $line = Get-Content -LiteralPath $envPath | Where-Object { $_ -match "^$Name=" } | Select-Object -First 1
    if (-not $line) { return $DefaultValue }
    return ($line -replace "^$Name=", '').Trim().Trim('"').Trim("'")
}

$apiContext = Get-DotEnvValue 'API_CONTEXT' (Join-Path $infraRoot '..\api_lixocerto')
if (-not [IO.Path]::IsPathRooted($apiContext)) {
    $apiContext = Join-Path $infraRoot $apiContext
}
$apiContext = (Resolve-Path -LiteralPath $apiContext).Path
$contratos = Join-Path $apiContext 'contratos\lixo_certo\v1'
$postmanDocs = Join-Path $apiContext 'docs\postman'

if (-not (Test-Path -LiteralPath $contratos)) { throw "Diretório de contratos não encontrado: $contratos" }
if (-not (Test-Path -LiteralPath $postmanDocs)) { throw "Documentação Postman não encontrada: $postmanDocs" }

New-Item -ItemType Directory -Force -Path (Join-Path $DiretorioPostman 'contratos\lixo_certo\v1') | Out-Null
Copy-Item -Path (Join-Path $contratos '*') -Destination (Join-Path $DiretorioPostman 'contratos\lixo_certo\v1') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $postmanDocs 'Lixo-Certo-API.postman_collection.json') -Destination $DiretorioPostman -Force
Copy-Item -LiteralPath (Join-Path $postmanDocs 'Lixo-Certo-API.postman_environment.json') -Destination $DiretorioPostman -Force

Write-Host 'Contratos e arquivos Postman preparados.' -ForegroundColor Green
Write-Host "Diretório de trabalho: $DiretorioPostman"
Write-Host 'No Postman, use New > gRPC Request e selecione os métodos pela definição compartilhada.'
