# Response — triage, case management & SOAR

When a detection fires, an analyst needs somewhere to work it and a playbook to follow.

## The loop this closes

```
detect (Wazuh) → alert → case (TheHive) → enrich (Cortex + MISP) → decide → contain
                    └──────────── automated by Shuffle (playbooks/) ───────────┘
```

- **TheHive** (`../stack/thehive/`) — cases, tasks, observables, timeline, TLP/severity.
- **Cortex** — analyzers (VirusTotal, AbuseIPDB, MISP) + responders (block IP, tag).
- **MISP** (`../stack/misp/`) — the intel that turns "an IP failed logons" into "a
  *known-malicious* IP failed logons then succeeded."
- **Shuffle** (`../stack/shuffle/`) — automates the triage in `playbooks/shuffle-triage.md`.

## Runbooks (NIST SP 800-61)

| Runbook | Trigger rule | Technique |
|---|---|---|
| `runbooks/bruteforce.md` | 100201 / 100210 | T1110 |
| `runbooks/phishing.md` | 100220 | T1566.001 → T1059 |
| `runbooks/suspicious-powershell.md` | 100230 | T1059.001 |
| `runbooks/lateral-movement.md` | correlated 4624 / Caldera | T1021 |

Each runbook maps back to the emulation that tests it, so a purple-team exercise is:
detonate → alert → open the matching runbook → work the case → measure → tune.

## Wiring order

1. Bring up TheHive + Cortex; create a Cortex org + API key; paste it into TheHive's
   `application.conf`; enable the VirusTotal/AbuseIPDB/MISP analyzers with your keys.
2. Bring up MISP; enable feeds; generate an auth key; wire it into Cortex's MISP analyzer,
   TheHive, and Wazuh's `custom-misp` integration.
3. Bring up Shuffle; build `playbooks/shuffle-triage.md`; paste its webhook into Wazuh.
4. Fire `../emulation/bruteforce.sh` and watch a case appear, enriched, end-to-end.
