# Runbook: Phishing With Execution

**Trigger:** Wazuh rule `100220` (Office app → script interpreter).
**Framework:** NIST SP 800-61. **Maps to:** T1566.001 → T1059. **Tested by:** `emulation/phishing/`.

## 1. Identify
- Alert: `winword.exe`/`excel.exe`/`outlook.exe` spawned `powershell.exe`/`cmd.exe`/etc.
- Capture: user, host, parent process, **full command line** (this is why 4688 cmdline +
  Sysmon matter), and any child network/DNS (EID 3/22).
- Correlate with GoPhish (or the mail gateway): who received/opened/clicked?

## 2. Scope
- Same lure to other users? Pivot on the attachment hash / sender in MISP + the SIEM.
- What did the spawned interpreter do — download (LOLBin rule `100240`), persist
  (`100260`), inject (`100270`), or touch LSASS (`100250`)?
- Any callback? Check Sysmon EID 3/22 and Suricata; run the destination through
  MISP/VirusTotal via Cortex.

## 3. Contain
- Isolate the affected endpoint.
- Block the sender + any C2 domain/IP (firewall + Wazuh active response).
- Purge the phishing mail from other mailboxes if it spread.

## 4. Eradicate
- Kill the interpreter and any spawned children; remove downloaded payloads (Sysmon 11).
- Remove persistence (Run keys, services, scheduled tasks).

## 5. Recover
- Restore the endpoint from snapshot if a payload executed.
- Reset the user's credentials (assume harvested if a landing page captured them).

## 6. Lessons learned
- Did `100220` fire before the payload's second stage (MTTD)? If not, the parent/child
  rule may need the interpreter list widened.
- Add the attachment hash + sender + C2 to MISP.
- Feed the lesson into user-awareness and the rule.
