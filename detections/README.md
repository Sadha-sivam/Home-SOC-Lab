# Detection engineering (detection-as-code)

This directory is the **source of truth** for detections — not the SIEM UI. Rules are
version-controlled, MITRE-tagged, and validated against emulated telemetry before they
go live (see `../emulation/`).

## Two layers, on purpose

| | Where | Why |
|---|---|---|
| **Single-event detections** | `sigma/` (portable YAML) | vendor-neutral; convert to any backend via `convert.sh` |
| **Stateful correlations** | `../stack/wazuh/custom-rules/local_rules.xml` | "brute force THEN success", frequency, `same_source_ip` — Sigma can't express these |

The Wazuh XML rules are **hand-authored from the same Sigma logic** and carry the same
MITRE tags. When you change one, change the other — git is what keeps them honest.

## Rule ↔ MITRE ↔ emulation map

| Sigma / Wazuh rule | Technique | Validated by |
|---|---|---|
| `proc_office_spawning_interpreter` / 100220 | T1566.001, T1059.001 | `emulation/phishing/` |
| `proc_powershell_suspicious_cmdline` / 100230 | T1059.001 | `Invoke-AtomicTest T1059.001` |
| `proc_lolbin_download_exec` / 100240 | T1105, T1218 | `Invoke-AtomicTest T1218.010` |
| `proc_lsass_credential_access` / 100250 | T1003.001 | `Invoke-AtomicTest T1003.001` |
| `reg_runkey_persistence` / 100260 | T1547.001 | `Invoke-AtomicTest T1547.001` |
| `auth_failed_logon_bruteforce` / 100200→100201 | T1110 | `emulation/bruteforce.sh` |
| `auth_ssh_bruteforce` / 100210 | T1110 | `emulation/bruteforce.sh` |
| `proc_shadow_read` | T1003.008 | `Invoke-AtomicTest T1003.008` |
| (network) 100500 + Suricata sids 9000001-5 | T1046/T1110/T1105 | `nmap`, `hydra` |
| (intel) 100600 | — | MISP IOC match on any emulation |

Keep this table in sync with `../coverage/attack-navigator-layer.json`.

## Workflow

```bash
pip install sigma-cli pysigma-backend-elasticsearch pysigma-pipeline-windows
./convert.sh validate     # lint before commit
./convert.sh              # emit backend queries to build/
```

1. Write/modify a rule in `sigma/` (stable UUID, `attack.tXXXX` tags).
2. If it needs correlation, add/adjust the Wazuh rule in `../stack/wazuh/custom-rules/`.
3. Detonate the matching emulation; confirm it fires (`wazuh-logtest` or the dashboard).
4. Generate benign activity; tune out false positives; record the FP rate.
5. Commit. Update the ATT&CK Navigator layer.

Baseline from the community **SigmaHQ** ruleset, then keep these lab-specific rules on top.
