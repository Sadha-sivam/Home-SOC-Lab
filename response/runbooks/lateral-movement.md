# Runbook: Lateral Movement

**Trigger:** correlated 4624 type-3 logons across hosts, SMB/WinRM bursts (Suricata
`9000002`), or a Caldera lateral-movement stage. **Maps to:** T1021, T1550, T1570.
**Tested by:** `emulation/caldera/setup.md`, `emulation/bruteforce.sh` (SMB spray).

## 1. Identify
- Signals: a single account authenticating (4624 logon type 3) to multiple hosts in a
  short window; remote service creation (7045 / Sysmon 13 `\Services\`); WinRM/PsExec/WMI
  process ancestry; SMB spray on the wire.
- Build the case around the **account** and the **first compromised host** (patient zero).

## 2. Scope
- Map the movement: which hosts did the account reach, in what order? Pivot on
  `user.name` + destination `host.name` across agents; overlay Zeek `conn.log`.
- Was it pass-the-hash / pass-the-ticket (T1550)? Look for anomalous Kerberos (4768/4769)
  and logons without a preceding interactive logon.
- Identify the credential source — tie back to an LSASS dump (`100250`) or brute force
  (`100201`) upstream.

## 3. Contain
- Disable the abused account across the domain; force a Kerberos TGT reset (KRBTGT
  double-reset if tickets were forged).
- Isolate every touched host, not just patient zero.
- Block the attacker's tooling paths (SMB/WinRM from unexpected sources) at the firewall.

## 4. Eradicate
- Remove remote-created services/tasks and any dropped tools on every touched host.
- Hunt for persistence on each (Run keys, services, scheduled tasks, WMI subscriptions).

## 5. Recover
- Restore affected hosts from clean snapshots.
- Reset all credentials the attacker could have touched; re-baseline privileged accounts.

## 6. Lessons learned
- Did the SOC alert on the **operation** or just scattered logons? If scattered, build a
  correlation rule that ties multi-host type-3 logons by the same account into one alert.
- Add attacker infra to MISP; review privileged-access segmentation on the SOC/enterprise
  boundary.
