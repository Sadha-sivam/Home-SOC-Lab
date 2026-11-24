# Runbook: Brute Force / Credential Access

**Trigger:** Wazuh rule `100201` (Windows brute-force-then-success) or `100210` (SSH).
**Framework:** NIST SP 800-61. **Maps to:** T1110. **Tested by:** `emulation/bruteforce.sh`.

## 1. Identify
- Alert says: >8 failed 4625 from one source, then a 4624 success (or SSH equivalent).
- Confirm in the SIEM: source IP, targeted account(s), exact time window, target host.
- Pull the observables into a TheHive case (auto-created via the Shuffle workflow, or
  manually): `source.ip`, `user.name`, `host.name`.

## 2. Scope
- Did that source IP touch **other** hosts? Query: `data.srcip: <ip>` across all agents.
- Did the account do anything **after** the successful logon? Look for process creation
  (Sysmon EID 1), new services (100260), LSASS access (100250), lateral movement (SMB/WinRM).
- Enrich the source IP: Cortex AbuseIPDB + MISP analyzers on the observable. A MISP hit
  (rule `100600`) escalates severity immediately.

## 3. Contain
- Disable / reset the targeted account (AD: `Disable-ADAccount`; Linux: `passwd -l`).
- Block the source IP at the firewall, or trigger Wazuh **active response**
  (`firewall-drop`) / the Shuffle responder.
- If the host shows post-logon activity, **isolate** it (VLAN quarantine / snapshot-hold).

## 4. Eradicate
- Remove any dropped artifacts or persistence (check Sysmon EID 11 file-creates and EID
  13 Run-key writes; auditd `T1543`/`shell_config` keys on Linux).
- Kill malicious processes; remove created services/scheduled tasks.

## 5. Recover
- Restore the host from a clean snapshot if compromise is confirmed.
- Re-enable the account with a strong credential + MFA; watch it for 24–48h.

## 6. Lessons learned
- Was MTTD acceptable (attack fired → alert)? If the composite fired late, tune the
  frequency/timeframe on rules `100200`/`100210`.
- Add the source IP to MISP as an event so future matches are instant.
- Update this runbook with anything that slowed you down.
