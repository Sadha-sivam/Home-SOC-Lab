# SOC metrics — measure it like a real SOC (§10)

Run the lab like a SOC by measuring it like one. Build these as saved searches /
visualizations on the Wazuh dashboard (Discover + Visualize on the `wazuh-alerts-*`
index) and pin them to an "SOC Ops" dashboard.

## Operational dashboards
| Panel | Query (Wazuh index `wazuh-alerts-*`) |
|---|---|
| Alert volume by rule | agg `count` split by `rule.id` (top 20) over time |
| Top source IPs | agg `count` by `data.srcip` |
| Auth failures over time | `rule.groups: authentication_failures` date histogram |
| MITRE technique heatmap | agg by `rule.mitre.id` |
| Agent health / coverage | `rule.groups: wazuh` + `Agents` app (active vs disconnected) |

## KPIs

**MTTD — mean time to detect** (attack fired → alert). You control the "attack fired"
timestamp from the emulation run; the alert timestamp is `timestamp` on the Wazuh alert.
```
MTTD = alert.timestamp  -  emulation_start_time
```
Log each emulation's start time (the runbooks and `run-atomics.ps1` print it) and diff.

**MTTR — mean time to respond** (alert → contained/closed). Pull from TheHive:
```
MTTR = case.closedAt  -  case.createdAt      # TheHive case metrics / API
```

**True-positive / false-positive ratio per rule.** Tag every worked case in TheHive as
TP or FP; group by the originating `rule.id`. A rule with a rising FP rate goes back to
`../detections/` for tuning (that's the §5.3 discipline, not optional).

**ATT&CK coverage %.** From `attack-navigator-layer.json`:
```
coverage% = (techniques scored 100)  /  (techniques you care about)  * 100
```
Use **DeTT&CT** for a data-source-driven view of what you *could* detect vs. what you do.

## Keep the map in git

`attack-navigator-layer.json` lives next to the rules. Every new detection updates the
layer in the same commit — the coverage matrix is exactly what a SOC manager reports on,
and here it's reproducible from version control.
