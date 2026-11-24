#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install Invoke-AtomicRedTeam and run the per-technique tests that validate this
  lab's detections. Run ON a victim (WKS01) AFTER telemetry + agent are in place.
.EXAMPLE
  ./run-atomics.ps1                 # run the mapped set with cleanup
  ./run-atomics.ps1 -Technique T1003.001
  ./run-atomics.ps1 -NoCleanup      # leave artifacts for investigation practice
.NOTES
  Snapshot the VM first. Everything here is offensive-by-design against YOUR lab only.
#>
[CmdletBinding()]
param(
  [string]$Technique,
  [switch]$NoCleanup
)
$ErrorActionPreference = 'Stop'

# Techniques mapped 1:1 to rules in ../../detections/README.md
$MappedSet = @(
  'T1059.001',  # Suspicious PowerShell        -> rule 100230
  'T1218.010',  # Regsvr32 (LOLBin)            -> rule 100240
  'T1003.001',  # LSASS memory dump            -> rule 100250
  'T1547.001',  # Run-key persistence          -> rule 100260
  'T1055'       # Process injection            -> rule 100270
)

if (-not (Get-Module -ListAvailable -Name Invoke-AtomicRedTeam)) {
  Write-Host "Installing Invoke-AtomicRedTeam + atomics..." -ForegroundColor Cyan
  Install-Module -Name Invoke-AtomicRedTeam -Scope CurrentUser -Force
  IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
  Install-AtomicRedTeam -getAtomics -Force
}
Import-Module Invoke-AtomicRedTeam -Force

$targets = if ($Technique) { @($Technique) } else { $MappedSet }

foreach ($t in $targets) {
  Write-Host "`n=== $t : checking prereqs ===" -ForegroundColor Cyan
  Invoke-AtomicTest $t -GetPrereqs
  Write-Host "=== $t : executing ===" -ForegroundColor Yellow
  Invoke-AtomicTest $t
  if (-not $NoCleanup) {
    Start-Sleep -Seconds 5   # let telemetry flush to the agent first
    Write-Host "=== $t : cleanup ===" -ForegroundColor DarkGray
    Invoke-AtomicTest $t -Cleanup
  }
}

Write-Host "`nDone. Now confirm the matching rules fired in the Wazuh dashboard" -ForegroundColor Green
Write-Host "(Security events, filter rule.id: 100230 / 100240 / 100250 / 100260 / 100270)."
