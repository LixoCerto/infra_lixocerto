param(
    [string]$DiretorioPostman = (Join-Path $HOME 'Postman\files\lixo-certo'),
    [string]$Email
)

$ErrorActionPreference = 'Stop'
$infraRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$postmanEnvPath = Join-Path $DiretorioPostman 'Lixo-Certo-API.postman_environment.json'

if (-not (Test-Path -LiteralPath $postmanEnvPath)) {
    throw "Ambiente Postman não encontrado. Execute .\scripts\preparar-postman.ps1 primeiro."
}

$ambiente = Get-Content -LiteralPath $postmanEnvPath -Raw | ConvertFrom-Json
function Get-PostmanValue([string]$Name, [string]$DefaultValue) {
    $valor = @($ambiente.values) | Where-Object { $_.key -eq $Name } | Select-Object -First 1
    if (-not $valor -or [string]::IsNullOrWhiteSpace([string]$valor.value)) { return $DefaultValue }
    return [string]$valor.value
}

if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Get-PostmanValue 'email_usuario' 'usuario@exemplo.test'
}

$senhaSegura = Read-Host "Senha da conta local '$Email'" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senhaSegura)
try {
    $senha = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

$env:LCR_LOGIN_EMAIL = $Email
$env:LCR_LOGIN_PASSWORD = $senha
try {
    $resultadoTexto = & node (Join-Path $infraRoot 'tools\login-postman.mjs') 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($resultadoTexto -join ' ').Trim())
    }
    $resultado = ($resultadoTexto -join '') | ConvertFrom-Json
}
catch {
    throw "Não foi possível executar Entrar pelo gRPC em grpc://127.0.0.1:50051. Confirme que a API está em execução, que a migration 022 foi aplicada e que a senha está correta. Detalhe: $($_.Exception.Message)"
}
finally {
    Remove-Item Env:LCR_LOGIN_EMAIL -ErrorAction SilentlyContinue
    Remove-Item Env:LCR_LOGIN_PASSWORD -ErrorAction SilentlyContinue
    $senha = $null
}

if ([string]::IsNullOrWhiteSpace($resultado.tokenAcesso) -or [string]::IsNullOrWhiteSpace($resultado.tokenAtualizacao)) {
    throw 'O login gRPC não retornou os tokens esperados.'
}

foreach ($nome in @('jwt_token', 'token_atualizacao')) {
    $variavel = @($ambiente.values) | Where-Object { $_.key -eq $nome } | Select-Object -First 1
    if (-not $variavel) {
        $variavel = [pscustomobject]@{ key = $nome; value = ''; enabled = $true; type = 'secret' }
        $ambiente.values += $variavel
    }
    $variavel.value = if ($nome -eq 'jwt_token') { $resultado.tokenAcesso } else { $resultado.tokenAtualizacao }
    $variavel.type = 'secret'
}

$emailVariavel = @($ambiente.values) | Where-Object { $_.key -eq 'email_usuario' } | Select-Object -First 1
if ($emailVariavel) { $emailVariavel.value = $Email }
$ambiente | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $postmanEnvPath -Encoding utf8

Write-Host "Login gRPC concluído para '$Email'; tokens gravados somente no ambiente local do Postman." -ForegroundColor Green
Write-Host 'Não copie os tokens para o GitHub, para arquivos do projeto ou para a conversa.' -ForegroundColor Yellow
Write-Host 'No Postman, mantenha authorization = Bearer {{jwt_token}} na aba Metadata.'
