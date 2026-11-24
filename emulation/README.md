# Adversary emulation (validation layer) — §6

You never trust a rule you haven't fired an attack at. Everything here runs from the
**attacker VLAN (99)** against the **enterprise VLAN (20)**, inside the lab only.

> **Snapshot every victim before a run.** The core loop is detonate → inspect → roll back.

| Tool | File | Validates |
|---|---|---|
| Atomic Red Team | `atomic/run-atomics.ps1` | per-technique rules (100230/100240/100250/100260/100270) |
| Brute force | `bruteforce.sh` | 100200→100201, 5720→100210, Suricata 9000002 |
| GoPhish + macro | `phishing/gophish-setup.md` | 100220 (Office→PowerShell), phishing chain |
| MITRE Caldera | `caldera/setup.md` | cross-stage **correlation** (the real test) |
| Port scan | `nmap -sS 10.10.20.0/24` (from Kali) | Suricata sid 9000001, rule 100500 |

## The discipline

For each detection:

1. **Snapshot** the victim.
2. **Detonate** the mapped emulation.
3. **Confirm** the rule fired (Wazuh dashboard, filter by `rule.id`). If not → fix the
   rule in `../detections/`, not the test.
4. **Generate benign activity** of the same shape; **tune** out false positives;
   record the FP rate.
5. **Work the alert as a case** in TheHive (`../response/runbooks/`) — this also times
   your MTTD/MTTR.
6. **Roll back** the snapshot.

Run a scheduled **purple-team** exercise (one scenario end-to-end) on a cadence. That
loop — not the pile of tools — is what makes this a SOC.

## Safety

Keep all of it inside the lab. Constrain the attacker VLAN's egress. Never point
brute-force or phishing tooling at anything you don't own.
