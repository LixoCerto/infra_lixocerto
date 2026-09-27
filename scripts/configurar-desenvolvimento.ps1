$ErrorActionPreference = 'Stop'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envPath = Join-Path $infraRoot '.env'

if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath (Join-Path $infraRoot '.env.exemplo') -Destination $envPath
}

$linhas = @(Get-Content -LiteralPath $envPath)

function Get-EnvValue([string]$Name) {
    $linha = $linhas | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $linha) { return $null }
    return ($linha -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

function Set-EnvValue([string]$Name, [string]$Value) {
    $encontrado = $false
    $novasLinhas = @(
        $linhas | ForEach-Object {
            if ($_ -match "^$([regex]::Escape($Name))=") {
                $encontrado = $true
                "$Name=$Value"
            } else {
                $_
            }
        }
    )
    if (-not $encontrado) { $novasLinhas += "$Name=$Value" }
    $script:linhas = $novasLinhas
}

function New-Secret([int]$Bytes = 32) {
    $buffer = New-Object byte[] $Bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return ([Convert]::ToBase64String($buffer) -replace '[^A-Za-z0-9]', '').Substring(0, 32)
}

function Ensure-Value([string]$Name, [string]$DefaultValue, [switch]$Secret) {
    $atual = Get-EnvValue $Name
    $deveGerar = [string]::IsNullOrWhiteSpace($atual) -or $atual -match '^(alterar_|gerar-com|seu-provedor|https://.*example)'
    if ($deveGerar) {
        Set-EnvValue $Name ($(if ($Secret) { New-Secret } else { $DefaultValue }))
    }
}

function Ensure-ExactValue([string]$Name, [string]$ExpectedValue) {
    if ((Get-EnvValue $Name) -ne $ExpectedValue) { Set-EnvValue $Name $ExpectedValue }
}

Ensure-Value 'REDIS_PASSWORD' 'local-redis' -Secret
Ensure-Value 'SEGREDO_JWT' 'local-segredo-jwt' -Secret
Ensure-ExactValue 'EMISSOR_JWT' 'lixo-certo-api'
Ensure-ExactValue 'AUDIENCIA_JWT' 'lixo-certo-client'
Ensure-ExactValue 'AMBIENTE_EXECUCAO' 'desenvolvimento'
Ensure-ExactValue 'VITE_API_BASE_URL' '/api/rpc'

$utf8SemBOM = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($envPath, ($linhas -join [Environment]::NewLine), $utf8SemBOM)

Write-Host 'Ambiente local configurado para JWT próprio da API.' -ForegroundColor Green
Write-Host "Arquivo local: $envPath"
Write-Host 'As senhas e o segredo JWT foram mantidos somente no .env local e não serão exibidos.' -ForegroundColor Yellow
