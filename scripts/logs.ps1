param(
    [ValidateSet('cache', 'api', 'gateway', 'frontend')]
    [string]$Servico = 'api',
    [switch]$Seguir
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

& (Join-Path $PSScriptRoot 'configurar-desenvolvimento.ps1')
$argumentos = @('--env-file', '..\api_lixocerto\.env', '--env-file', '..\frontend_lixocerto\.env', '-f', 'compose.yml', '--profile', 'app', 'logs', '--tail=100')
if ($Seguir) { $argumentos += '--follow' }
$argumentos += $Servico
docker compose @argumentos
