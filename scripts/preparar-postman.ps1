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

$contratosDestino = Join-Path $DiretorioPostman 'contratos\lixo_certo\v1'
New-Item -ItemType Directory -Force -Path $contratosDestino | Out-Null
Copy-Item -Path (Join-Path $contratos '*') -Destination $contratosDestino -Recurse -Force

$arquivosPostman = @(
    'Lixo-Certo-API.postman.proto',
    'Lixo-Certo-API.grpc.manifest.json',
    'Lixo-Certo-API.postman_environment.json',
    'README.md'
)
$tokensPostmanExistentes = @{}
$destinoAmbiente = Join-Path $DiretorioPostman 'Lixo-Certo-API.postman_environment.json'
if (Test-Path -LiteralPath $destinoAmbiente) {
    try {
        $ambienteExistente = Get-Content -LiteralPath $destinoAmbiente -Raw | ConvertFrom-Json
        foreach ($nomeToken in @('jwt_token', 'token_atualizacao')) {
            $valorToken = @($ambienteExistente.values) |
                Where-Object { $_.key -eq $nomeToken -and -not [string]::IsNullOrWhiteSpace($_.value) } |
                Select-Object -ExpandProperty value -First 1
            if (-not [string]::IsNullOrWhiteSpace($valorToken)) {
                $tokensPostmanExistentes[$nomeToken] = $valorToken
            }
        }
    } catch {
        Write-Host 'O ambiente Postman existente não pôde ser lido; será substituído pelo modelo.' -ForegroundColor Yellow
    }
}
foreach ($arquivo in $arquivosPostman) {
    $origem = Join-Path $postmanDocs $arquivo
    if (-not (Test-Path -LiteralPath $origem)) {
        throw "Artefato Postman não encontrado: $origem"
    }
    Copy-Item -LiteralPath $origem -Destination $DiretorioPostman -Force
}

if ($tokensPostmanExistentes.Count -gt 0) {
    $ambienteNovo = Get-Content -LiteralPath $destinoAmbiente -Raw | ConvertFrom-Json
    foreach ($itemToken in $tokensPostmanExistentes.GetEnumerator()) {
        $variavelToken = @($ambienteNovo.values) | Where-Object { $_.key -eq $itemToken.Key } | Select-Object -First 1
        if ($variavelToken) {
            $variavelToken.value = $itemToken.Value
            $variavelToken.type = 'secret'
        }
    }
    $ambienteNovo | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $destinoAmbiente -Encoding utf8
}

# Evita que uma execução anterior deixe a coleção HTTP enganosa no diretório de trabalho.
$colecaoLegada = Join-Path $DiretorioPostman 'Lixo-Certo-API.postman_collection.json'
if (Test-Path -LiteralPath $colecaoLegada) {
    Remove-Item -LiteralPath $colecaoLegada -Force
    Write-Host 'Coleção HTTP legada removida do diretório do Postman.' -ForegroundColor Yellow
}

Write-Host 'Contratos, definição raiz, catálogo e ambiente Postman preparados.' -ForegroundColor Green
Write-Host "Diretório de trabalho: $DiretorioPostman"
Write-Host 'A coleção nativa deve ser criada no cliente: New > gRPC > grpc://{{grpc_host}} > Invoke > Save As.'
