# Build order — so you don't drown (§13)

Do steps 1–4 before touching 5–7. A SIEM with clean telemetry and version-controlled
rules is worth more than a pile of half-wired tools.

### 1. Foundation
Hypervisor + segmented network + firewall (`network-segmentation.md`). Get the VLANs and
firewall rules working; ping-test the allow/deny matrix.

### 2. Telemetry
- AD domain on DC01 (`../telemetry/windows/audit-policy.md`).
- Sysmon + advanced audit policy + PowerShell logging on every Windows host
  (`../telemetry/windows/install-telemetry.ps1`).
- auditd on LNX01 (`../telemetry/linux/install-telemetry.sh`).
- Suricata + Zeek on the sensor (`../telemetry/network/`).
- **NTP everywhere** — skewed clocks destroy correlation.

### 3. SIEM
Stand up Wazuh (`./soc.ps1 up core`). Enroll every agent. Push `shared-agent.conf`.
Confirm all sources ingest cleanly with proper parsing (Sysmon channel, Suricata EVE,
auditd) and that agents show `active`.

### 4. Detection-as-code
Git repo (this one), Sigma baseline + `custom-rules/local_rules.xml`, MITRE tags, the
first correlation rules. Validate each with `wazuh-logtest`.

### 5. Emulation
Atomic Red Team → brute force → GoPhish → Caldera (`../emulation/`). Validate and **tune**
every rule. No rule is trusted until an attack has fired at it.

### 6. Response stack
TheHive + Cortex, then MISP enrichment, then Shuffle automation (`../response/`,
`../stack/`). Wire the `detect → alert → case → enrich → decide` loop.

### 7. Measure
Dashboards, MTTD/MTTR, ATT&CK coverage map (`../coverage/`).

### 8. Operate
Run scheduled purple-team exercises: detonate, triage a case end-to-end, write up lessons
learned. Snapshot before, roll back after.

---

**Fast path to "a working SIEM you can attack":** 1 → 2 (one Windows victim only) → 3 →
`emulation/atomic/run-atomics.ps1`. That proves the whole telemetry→detection spine before
you invest in the response stack.
