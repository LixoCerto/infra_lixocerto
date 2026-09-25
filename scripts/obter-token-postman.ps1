param(
    [string]$DiretorioPostman = (Join-Path $HOME 'Postman\files\lixo-certo'),
    [switch]$Administrador,
    [string]$Usuario
)

$ErrorActionPreference = 'Stop'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envPath = Join-Path $infraRoot '.env'
$postmanEnvPath = Join-Path $DiretorioPostman 'Lixo-Certo-API.postman_environment.json'

if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Arquivo .env não encontrado. Execute .\scripts\configurar-desenvolvimento.ps1 primeiro."
}
if (-not (Test-Path -LiteralPath $postmanEnvPath)) {
    throw "Ambiente Postman não encontrado. Execute .\scripts\preparar-postman.ps1 primeiro."
}

function Get-DotEnvValue([string]$Name, [string]$DefaultValue) {
    $line = Get-Content -LiteralPath $envPath | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) { return $DefaultValue }
    return ($line -replace "^$([regex]::Escape($Name))=", '').Trim().Trim('"').Trim("'")
}

if ([string]::IsNullOrWhiteSpace($Usuario)) {
    $Usuario = if ($Administrador) {
        Get-DotEnvValue 'KEYCLOAK_DEV_ADMIN_USERNAME' 'administrador'
    } else {
        Get-DotEnvValue 'KEYCLOAK_DEV_USER_USERNAME' 'usuario'
    }
}

$senhaSegura = Read-Host "Senha do usuário Keycloak '$Usuario'" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senhaSegura)
try {
    $senha = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

$porta = Get-DotEnvValue 'KEYCLOAK_PORT' '8081'
$endpoint = "http://127.0.0.1:$porta/realms/lixo-certo/protocol/openid-connect/token"
$body = @{
    grant_type = 'password'
    client_id = 'lixo-certo-postman'
    username = $Usuario
    password = $senha
    scope = 'openid profile email'
}

try {
    $resposta = Invoke-RestMethod -Method Post -Uri $endpoint -ContentType 'application/x-www-form-urlencoded' -Body $body
}
catch {
    throw "Não foi possível obter o token no Keycloak ($endpoint). Verifique se o Docker está em execução, se o realm foi importado e se a senha está correta."
}

if ([string]::IsNullOrWhiteSpace($resposta.access_token)) {
    throw 'O Keycloak não retornou access_token.'
}

$ambiente = Get-Content -LiteralPath $postmanEnvPath -Raw | ConvertFrom-Json
$variavel = @($ambiente.values) | Where-Object { $_.key -eq 'jwt_token' } | Select-Object -First 1
if (-not $variavel) { throw "A variável jwt_token não existe em $postmanEnvPath" }
$variavel.value = $resposta.access_token
$variavel.type = 'secret'
$ambiente | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $postmanEnvPath -Encoding utf8

Write-Host "Token obtido para '$Usuario' e gravado somente no ambiente local do Postman." -ForegroundColor Green
Write-Host 'Não copie o token para o GitHub, para arquivos do projeto ou para a conversa.' -ForegroundColor Yellow
Write-Host 'No Postman, mantenha o metadado authorization com o valor Bearer {{jwt_token}} e clique em Invoke.'
