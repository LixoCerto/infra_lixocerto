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
    $deveGerar = [string]::IsNullOrWhiteSpace($atual) -or $atual -match '^(alterar_|seu-provedor|https://.*example)'
    if ($deveGerar) {
        Set-EnvValue $Name ($(if ($Secret) { New-Secret } else { $DefaultValue }))
    }
}

function Ensure-ExactValue([string]$Name, [string]$ExpectedValue) {
    if ((Get-EnvValue $Name) -ne $ExpectedValue) {
        Set-EnvValue $Name $ExpectedValue
    }
}

Ensure-Value 'KEYCLOAK_PORT' '8081'
Ensure-Value 'REDIS_PASSWORD' 'local-redis' -Secret
Ensure-Value 'KEYCLOAK_ADMIN_USERNAME' 'admin'
Ensure-Value 'KEYCLOAK_ADMIN_PASSWORD' 'local-keycloak-admin' -Secret
Ensure-Value 'KEYCLOAK_DEV_USER_USERNAME' 'usuario'
Ensure-Value 'KEYCLOAK_DEV_USER_EMAIL' 'usuario@lixo-certo.local'
Ensure-Value 'KEYCLOAK_DEV_USER_PASSWORD' 'local-keycloak-usuario' -Secret
Ensure-Value 'KEYCLOAK_DEV_ADMIN_USERNAME' 'administrador'
Ensure-Value 'KEYCLOAK_DEV_ADMIN_EMAIL' 'administrador@lixo-certo.local'
Ensure-Value 'KEYCLOAK_DEV_ADMIN_PASSWORD' 'local-keycloak-administrador' -Secret
Ensure-Value 'KEYCLOAK_VOLUME_NAME' 'lcr-keycloak-data'
Ensure-Value 'MAILPIT_WEB_PORT' '8025'
Ensure-Value 'SMTP_FROM' 'nao-responda@lixo-certo.local'
Ensure-ExactValue 'AMBIENTE_EXECUCAO' 'desenvolvimento'
Ensure-ExactValue 'VITE_OIDC_ISSUER' 'http://localhost:8081/realms/lixo-certo'
Ensure-ExactValue 'VITE_OIDC_CLIENT_ID' 'lixo-certo-frontend'
Ensure-ExactValue 'VITE_OIDC_AUDIENCE' 'lixo-certo-api'
Ensure-ExactValue 'VITE_OIDC_SCOPE' 'openid profile email'
Ensure-ExactValue 'VITE_OIDC_REDIRECT_URI' 'http://localhost:3000/callback'
Ensure-ExactValue 'VITE_OIDC_POST_LOGOUT_REDIRECT_URI' 'http://localhost:3000/login'
Ensure-Value 'VITE_OIDC_GOOGLE_ENABLED' 'false'
Ensure-ExactValue 'VITE_MAILPIT_URL' "http://localhost:$(Get-EnvValue 'MAILPIT_WEB_PORT')"
Ensure-ExactValue 'EMISSOR_OIDC' 'http://localhost:8081/realms/lixo-certo'
Ensure-ExactValue 'AUDIENCIA_OIDC' 'lixo-certo-api'
Ensure-ExactValue 'ENDERECO_JWKS' 'http://keycloak:8080/realms/lixo-certo/protocol/openid-connect/certs'
Ensure-ExactValue 'DOMINIO_EMAIL_OIDC_DESENVOLVIMENTO' 'lixo-certo.local'

$utf8SemBOM = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($envPath, ($linhas -join [Environment]::NewLine), $utf8SemBOM)

Write-Host 'Ambiente local OIDC configurado para o Keycloak.' -ForegroundColor Green
Write-Host "Arquivo local: $envPath"
Write-Host "Usuário comum: $(Get-EnvValue 'KEYCLOAK_DEV_USER_USERNAME')"
Write-Host "Usuário administrador: $(Get-EnvValue 'KEYCLOAK_DEV_ADMIN_USERNAME')"
Write-Host 'As senhas foram mantidas somente no .env local e não serão exibidas.' -ForegroundColor Yellow
