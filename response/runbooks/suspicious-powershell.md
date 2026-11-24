# Runbook: Suspicious PowerShell

**Trigger:** Wazuh rule `100230` (obfuscated / download-exec PowerShell).
**Framework:** NIST SP 800-61. **Maps to:** T1059.001, T1027. **Tested by:** `Invoke-AtomicTest T1059.001`.

## 1. Identify
- Alert: PowerShell with `-enc`, `FromBase64String`, `-w hidden`, `DownloadString`, `IEX`, etc.
- Decode the command: grab the Base64 from the command line (or the Script Block Logging
  EID 4104 event, which shows the deobfuscated block) and read what it actually does.
- Record: user, host, parent process (was it Office → phishing overlap?), decoded intent.

## 2. Scope
- Same encoded pattern on other hosts (hunt the decoded strings / URLs)?
- Did it download (rule `100240`), persist, inject (`100270`), or dump creds (`100250`)?
- Extract IOCs from the decoded block (URLs, IPs, filenames) → check MISP/VT via Cortex.

## 3. Contain
- Isolate the host. Block any C2 endpoint the script contacted.
- If the script established persistence, disable it before it re-runs.

## 4. Eradicate
- Kill the PowerShell process tree; remove downloaded files and persistence.
- If AMSI/Script Block Logging shows a known tool (Empire/Cobalt/etc.), treat as full
  compromise.

## 5. Recover
- Restore from snapshot on confirmed payload execution; rotate any exposed credentials.

## 6. Lessons learned
- Confirm Script Block Logging (4104) captured the deobfuscated block — if not, fix the
  PowerShell logging GPO (`telemetry/windows/audit-policy.md`).
- Add decoded IOCs to MISP; tighten the `100230` pattern if the sample evaded it.
