param(
    [ValidateSet('cache', 'api', 'gateway', 'frontend')]
    [string]$Servico = 'api',
    [switch]$Seguir
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path -LiteralPath '.env')) {
    throw 'Arquivo .env não encontrado. Execute iniciar.ps1 primeiro.'
}

$argumentos = @('--env-file', '.env', '-f', 'compose.yml', '--profile', 'app', 'logs', '--tail=100')
if ($Seguir) { $argumentos += '--follow' }
$argumentos += $Servico
docker compose @argumentos
