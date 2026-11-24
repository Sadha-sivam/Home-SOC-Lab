# Windows audit policy & AD domain (telemetry §3.1)

`install-telemetry.ps1` sets everything below **per host**. On a domain you set it
**once via GPO** so every machine inherits it. This file is the domain runbook.

## 1. Stand up the domain (DC01)

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "lab.local" -InstallDNS
# after reboot, create an OU + a few users so GPO scoping is realistic
New-ADOrganizationalUnit -Name "Lab" -Path "DC=lab,DC=local"
1..3 | % { New-ADUser -Name "user$_" -SamAccountName "user$_" -Path "OU=Lab,DC=lab,DC=local" `
  -AccountPassword (ConvertTo-SecureString "P@ssw0rd$_!" -AsPlainText -Force) -Enabled $true }
```

Join SRV01, WKS01, WKS02 to `lab.local`.

## 2. Advanced audit policy via GPO

`gpmc.msc` → new GPO linked to the domain (or the Lab OU) →
`Computer Configuration → Policies → Windows Settings → Security Settings → Advanced Audit Policy Configuration`.
Enable **Success + Failure** for:

| Category | Subcategory |
|---|---|
| Account Logon | Credential Validation; Kerberos Authentication Service; Kerberos Service Ticket Operations |
| Logon/Logoff | Logon; Logoff (Success); Special Logon; Account Lockout |
| Detailed Tracking | Process Creation; Process Termination (Success) |
| Object Access | File System; Registry *(scope tightly — noisy)* |
| Account Management | User Account Management; Security Group Management |
| Policy Change | Audit Policy Change; Authentication Policy Change |
| Privilege Use | Sensitive Privilege Use |

## 3. Command line in 4688

Same GPO →
`Computer Configuration → Administrative Templates → System → Audit Process Creation` →
**"Include command line in process creation events" = Enabled**.

Without this, 4688 events have no command line and half the detections are blind.

## 4. PowerShell logging

Same GPO →
`Computer Configuration → Administrative Templates → Windows Components → Windows PowerShell`:

- **Turn on Module Logging** = Enabled, module names = `*` → EID 4103
- **Turn on PowerShell Script Block Logging** = Enabled → EID 4104
- **Turn on PowerShell Transcription** = Enabled, output dir = a locked-down share

## 5. Sysmon at scale

Deploy `sysmonconfig.xml` via a GPO startup script or your config-management tool.
Update the config later without reinstall: `sysmon64.exe -c sysmonconfig.xml`.

## Verify

```powershell
auditpol /get /category:* | Select-String "Enable"
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1
```

These channels are collected by the Wazuh agent via `stack/wazuh/shared-agent.conf`.
