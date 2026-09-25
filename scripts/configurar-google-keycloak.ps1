param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [Security.SecureString]$ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute .\scripts\configurar-desenvolvimento.ps1 primeiro.'
}

function Get-EnvValue([string]$Name, [string]$DefaultValue = '') {
    $linha = Get-Content -LiteralPath '.env' | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $linha) { return $DefaultValue }
    return ($linha -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

function Set-EnvValue([string]$Name, [string]$Value) {
    $linhas = @(Get-Content -LiteralPath '.env')
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
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Resolve-Path '.env'), ($novasLinhas -join [Environment]::NewLine), $utf8SemBom)
}

$portaKeycloak = Get-EnvValue 'KEYCLOAK_PORT' '8081'
$adminUsuario = Get-EnvValue 'KEYCLOAK_ADMIN_USERNAME' 'admin'
$adminSenha = Get-EnvValue 'KEYCLOAK_ADMIN_PASSWORD'
if ([string]::IsNullOrWhiteSpace($adminSenha)) {
    throw 'KEYCLOAK_ADMIN_PASSWORD não está configurada no .env local.'
}

$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
try {
    $segredoGoogle = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

$baseUrl = "http://127.0.0.1:$portaKeycloak"
try {
    $token = Invoke-RestMethod -Method Post -Uri "$baseUrl/realms/master/protocol/openid-connect/token" -ContentType 'application/x-www-form-urlencoded' -Body @{
        grant_type = 'password'
        client_id = 'admin-cli'
        username = $adminUsuario
        password = $adminSenha
    }

    $cabecalhos = @{ Authorization = "Bearer $($token.access_token)" }
    $provedor = @{
        alias = 'google'
        displayName = 'Google'
        providerId = 'google'
        enabled = $true
        trustEmail = $true
        storeToken = $false
        addReadTokenRoleOnCreate = $false
        authenticateByDefault = $false
        firstBrokerLoginFlowAlias = 'first broker login'
        config = @{
            clientId = $ClientId
            clientSecret = $segredoGoogle
            defaultScope = 'openid profile email'
            syncMode = 'IMPORT'
            useJwksUrl = 'true'
        }
    }
    $json = $provedor | ConvertTo-Json -Depth 5
    $endpoint = "$baseUrl/admin/realms/lixo-certo/identity-provider/instances/google"

    try {
        Invoke-RestMethod -Method Get -Uri $endpoint -Headers $cabecalhos | Out-Null
        Invoke-RestMethod -Method Put -Uri $endpoint -Headers $cabecalhos -ContentType 'application/json' -Body $json | Out-Null
        $acao = 'atualizado'
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 404) {
            Invoke-RestMethod -Method Post -Uri "$baseUrl/admin/realms/lixo-certo/identity-provider/instances" -Headers $cabecalhos -ContentType 'application/json' -Body $json | Out-Null
            $acao = 'criado'
        } else {
            throw
        }
    }

    Set-EnvValue 'VITE_OIDC_GOOGLE_ENABLED' 'true'
    docker compose --env-file .env -f compose.yml --profile app up -d --build frontend
    if ($LASTEXITCODE -ne 0) { throw 'O provedor foi configurado, mas o rebuild do frontend falhou.' }

    Write-Host "Provedor Google $acao no Keycloak e frontend reconstruído." -ForegroundColor Green
    Write-Host 'O Client Secret foi usado somente em memória e não foi gravado no .env, Git ou saída do terminal.' -ForegroundColor Green
} finally {
    $segredoGoogle = $null
    $adminSenha = $null
}
