[CmdletBinding()]
param(
    [switch]$Start
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptRoot '.env'
$envExample = Join-Path $scriptRoot '.env.example'

function Set-EnvValue {
    param([string]$Name, [string]$Value)
    $lines = if (Test-Path -LiteralPath $envFile) { @(Get-Content -LiteralPath $envFile) } else { @() }
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($Name))=") {
            $lines[$i] = "$Name=$Value"
            $found = $true
            break
        }
    }
    if (-not $found) { $lines += "$Name=$Value" }
    Set-Content -LiteralPath $envFile -Value $lines -Encoding utf8
}

function Get-EnvValue {
    param([string]$Name)
    $line = @(Get-Content -LiteralPath $envFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=" }) | Select-Object -First 1
    if ($null -eq $line) { return $null }
    return ($line -replace "^$([regex]::Escape($Name))=", '')
}

function Ensure-Network {
    docker network inspect io_thingsboard_edge *> $null
    if ($LASTEXITCODE -ne 0) {
        docker network create --driver bridge --subnet 172.30.66.0/24 --gateway 172.30.66.1 io_thingsboard_edge | Out-Null
    }
}

function Ensure-Volume {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
    docker volume inspect $Name *> $null
    if ($LASTEXITCODE -ne 0) { docker volume create $Name | Out-Null }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker nao foi encontrado no PATH.' }
if (-not (Test-Path -LiteralPath $envFile)) {
    if (-not (Test-Path -LiteralPath $envExample)) { throw '.env.example nao foi encontrado.' }
    Copy-Item -LiteralPath $envExample -Destination $envFile
    Set-EnvValue -Name 'DB_PASSWORD' -Value ([guid]::NewGuid().ToString('N'))
    Set-EnvValue -Name 'PGADMIN_PASSWORD' -Value ([guid]::NewGuid().ToString('N'))
}

# The local Central is reachable directly by service name on the shared
# io_thingsboard network. This avoids host-only DNS/IPv6 resolution issues.
Set-EnvValue -Name 'TB_SERVER' -Value 'thingsboard'
Set-EnvValue -Name 'PORT_COAP_START' -Value '6583'
Set-EnvValue -Name 'PORT_COAP_END' -Value '6588'
Ensure-Network
@('VOLUME_DB','VOLUME_EDGE','VOLUME_LOG','VOLUME_BACKUP','VOLUME_PGADMIN') | ForEach-Object { Ensure-Volume (Get-EnvValue $_) }

$key = Get-EnvValue 'TB_EDGE_KEY'
$secret = Get-EnvValue 'TB_EDGE_SECRET'
$ready = $key -and $secret -and $key -ne 'GET_IN_TB_SERVER' -and $secret -ne 'GET_IN_TB_SERVER'
if ($Start) {
    if (-not $ready) { throw "Preencha TB_EDGE_KEY e TB_EDGE_SECRET em $envFile antes de usar -Start." }
    Push-Location $scriptRoot
    try { docker compose up -d --wait }
    finally { Pop-Location }
} else {
    Write-Host "Ambiente preparado. Preencha TB_EDGE_KEY e TB_EDGE_SECRET em $envFile e execute .\bootstrap.ps1 -Start."
}
