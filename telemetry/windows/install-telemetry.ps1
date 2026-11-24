#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Turn a Windows victim host into a high-quality telemetry source in one run:
  Sysmon (curated config) + advanced audit policy + 4688 command line + PowerShell
  logging. Run on WKS01/WKS02/SRV01/DC01 before enrolling the Wazuh agent.
.NOTES
  Sysmon is downloaded from Microsoft Sysinternals (official). If your host is
  offline, drop Sysmon.exe next to this script and pass -SysmonPath.
#>
[CmdletBinding()]
param(
  [string]$SysmonConfig = "$PSScriptRoot\sysmonconfig.xml",
  [string]$SysmonPath,
  [string]$TranscriptShare = "C:\PSTranscripts"
)
$ErrorActionPreference = 'Stop'

function Section($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# --- 1. Sysmon ---------------------------------------------------------------
Section "Sysmon"
if (-not $SysmonPath) {
  $SysmonPath = "$env:TEMP\Sysmon64.exe"
  if (-not (Test-Path $SysmonPath)) {
    Write-Host "Downloading Sysmon from Sysinternals..."
    $zip = "$env:TEMP\Sysmon.zip"
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath "$env:TEMP\Sysmon" -Force
    $SysmonPath = "$env:TEMP\Sysmon\Sysmon64.exe"
  }
}
if (-not (Test-Path $SysmonConfig)) { throw "Sysmon config not found: $SysmonConfig" }

$installed = Get-Service -Name Sysmon64, Sysmon -ErrorAction SilentlyContinue
if ($installed) {
  Write-Host "Sysmon already installed - updating config."
  & $SysmonPath -c $SysmonConfig
}
else {
  & $SysmonPath -accepteula -i $SysmonConfig
}

# --- 2. Advanced audit policy (matches guide section 3.1) --------------------
Section "Advanced audit policy"
$subcats = @{
  'Credential Validation'          = 'both'
  'Kerberos Authentication Service' = 'both'
  'Kerberos Service Ticket Operations' = 'both'
  'Logon'                          = 'both'
  'Logoff'                         = 'success'
  'Special Logon'                  = 'both'
  'Process Creation'               = 'both'
  'Process Termination'            = 'success'
  'Account Lockout'                = 'both'
  'User Account Management'        = 'both'
  'Security Group Management'      = 'both'
  'Audit Policy Change'            = 'both'
  'Authentication Policy Change'   = 'both'
  'Sensitive Privilege Use'        = 'both'
}
foreach ($name in $subcats.Keys) {
  $mode = $subcats[$name]
  $s = if ($mode -in 'both', 'success') { 'enable' } else { 'disable' }
  $f = if ($mode -in 'both', 'failure') { 'enable' } else { 'disable' }
  auditpol /set /subcategory:"$name" /success:$s /failure:$f | Out-Null
}
Write-Host "Advanced audit subcategories set."

# --- 3. Command line in 4688 process-creation events -------------------------
Section "Command-line capture (EID 4688)"
$auditKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
New-Item -Path $auditKey -Force | Out-Null
New-ItemProperty -Path $auditKey -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -PropertyType DWord -Force | Out-Null

# --- 4. PowerShell logging (module + script block + transcription) -----------
Section "PowerShell logging"
$psBase = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
# Script block logging (EID 4104)
$sb = "$psBase\ScriptBlockLogging"
New-Item -Path $sb -Force | Out-Null
New-ItemProperty -Path $sb -Name 'EnableScriptBlockLogging' -Value 1 -PropertyType DWord -Force | Out-Null
# Module logging (EID 4103) for all modules
$ml = "$psBase\ModuleLogging"
New-Item -Path "$ml\ModuleNames" -Force | Out-Null
New-ItemProperty -Path $ml -Name 'EnableModuleLogging' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$ml\ModuleNames" -Name '*' -Value '*' -PropertyType String -Force | Out-Null
# Transcription to a share/folder
$tr = "$psBase\Transcription"
New-Item -Path $tr -Force | Out-Null
if (-not (Test-Path $TranscriptShare)) { New-Item -ItemType Directory -Path $TranscriptShare -Force | Out-Null }
New-ItemProperty -Path $tr -Name 'EnableTranscripting' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $tr -Name 'EnableInvocationHeader' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $tr -Name 'OutputDirectory' -Value $TranscriptShare -PropertyType String -Force | Out-Null

Section "Done"
Write-Host "Telemetry configured. Verify with:  auditpol /get /category:*  and  Get-Service Sysmon64" -ForegroundColor Green
Write-Host "Next: install the Wazuh agent pointing at the manager (see ../../stack/wazuh/README.md)."
