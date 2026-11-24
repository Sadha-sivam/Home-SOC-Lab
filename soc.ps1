#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Orchestrator for the home SOC lab stack.
.EXAMPLE
  ./soc.ps1 up core         # Wazuh SIEM only
  ./soc.ps1 up all          # every layer
  ./soc.ps1 up misp         # a single layer
  ./soc.ps1 down all
  ./soc.ps1 status
  ./soc.ps1 logs wazuh
  ./soc.ps1 certs           # (re)generate Wazuh indexer certs
#>
param(
  [Parameter(Position = 0)][ValidateSet('up', 'down', 'status', 'logs', 'certs', 'help')]
  [string]$Action = 'help',
  [Parameter(Position = 1)][string]$Layer = 'core'
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$EnvFile = Join-Path $Root '.env'

# Map layer name -> compose dir. 'core' = wazuh; 'all' expands below.
$Layers = [ordered]@{
  wazuh   = 'stack/wazuh'
  thehive = 'stack/thehive'
  misp    = 'stack/misp'
  shuffle = 'stack/shuffle'
}
$Aliases = @{ core = @('wazuh'); all = @('wazuh', 'thehive', 'misp', 'shuffle') }

function Resolve-Layers([string]$name) {
  if ($Aliases.ContainsKey($name)) { return $Aliases[$name] }
  if ($Layers.Contains($name)) { return @($name) }
  throw "Unknown layer '$name'. Use: core, all, $($Layers.Keys -join ', ')"
}

function Require-Env {
  if (-not (Test-Path $EnvFile)) {
    throw ".env not found. Run: cp .env.example .env  (then edit passwords)"
  }
}

function Compose([string]$dir, [string[]]$args) {
  $composeDir = Join-Path $Root $dir
  Push-Location $composeDir
  try { docker compose --env-file $EnvFile @args }
  finally { Pop-Location }
}

# The indexer/OpenSearch refuses to start unless the host mmap limit is raised.
# On Docker Desktop / WSL2 the setting lives in the docker-desktop distro.
function Ensure-MaxMapCount {
  try {
    $cur = (wsl -d docker-desktop sysctl -n vm.max_map_count) 2>$null
    if ($cur -and [int]$cur -lt 262144) {
      Write-Host "Raising vm.max_map_count ($cur -> 262144) in docker-desktop..." -ForegroundColor Yellow
      wsl -d docker-desktop sysctl -w vm.max_map_count=262144 | Out-Null
    }
  }
  catch {
    Write-Warning "Could not set vm.max_map_count automatically. If the indexer crash-loops, run:"
    Write-Warning "  wsl -d docker-desktop sysctl -w vm.max_map_count=262144"
  }
}

function Generate-WazuhCerts {
  $certDir = Join-Path $Root 'stack/wazuh/config/wazuh_indexer_ssl_certs'
  if (Test-Path (Join-Path $certDir 'root-ca.pem')) {
    Write-Host "Wazuh certs already present (delete $certDir to regenerate)." -ForegroundColor Green
    return
  }
  Write-Host "Generating Wazuh indexer certificates..." -ForegroundColor Cyan
  Compose 'stack/wazuh' @('-f', 'generate-indexer-certs.yml', 'run', '--rm', 'generator')
}

switch ($Action) {
  'certs' { Require-Env; Generate-WazuhCerts }

  'up' {
    Require-Env
    foreach ($l in Resolve-Layers $Layer) {
      if ($l -eq 'wazuh') { Ensure-MaxMapCount; Generate-WazuhCerts }
      Write-Host "==> up: $l" -ForegroundColor Cyan
      Compose $Layers[$l] @('up', '-d')
    }
    Write-Host "`nUp. Check ./soc.ps1 status  - dashboards may take 1-2 min to be reachable." -ForegroundColor Green
  }

  'down' {
    Require-Env
    foreach ($l in Resolve-Layers $Layer) {
      Write-Host "==> down: $l" -ForegroundColor Cyan
      Compose $Layers[$l] @('down')
    }
  }

  'status' {
    foreach ($l in $Layers.Keys) {
      Write-Host "== $l ==" -ForegroundColor Cyan
      Compose $Layers[$l] @('ps')
    }
  }

  'logs' {
    $l = if ($Layer -eq 'core') { 'wazuh' } else { $Layer }
    Compose $Layers[$l] @('logs', '-f', '--tail', '100')
  }

  default {
    Get-Help $PSCommandPath -Detailed
  }
}
