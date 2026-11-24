# Shuffle playbook: alert triage + enrichment + case creation

Automating triage is what modern SOCs measure themselves on. This is the canonical
first workflow (§9). Build it in Shuffle (`stack/shuffle/`, drag-and-drop) as the node
sequence below, then wire its webhook into Wazuh.

## Flow

```
Trigger: Webhook  (Wazuh posts level>=7 alerts here)
   │
   ▼
[1] Parse alert         extract rule.id, rule.description, agent.name,
                        data.srcip / data.win.eventdata.destinationIp, hashes, user
   │
   ▼
[2] Enrich (parallel)
     ├─ MISP app:       search each IP/domain/hash          -> reputation, tags
     ├─ Cortex app:     run VirusTotal + AbuseIPDB analyzers -> scores
   │
   ▼
[3] Decision (condition on max reputation / VT positives / MISP hit)
     ├─ MALICIOUS ──▶ [4a] TheHive: create case (title = rule.description,
     │                      severity=High, observables attached, enrichment in a task)
     │               [4b] (optional) Active response: Wazuh firewall-drop or
     │                      firewall app -> block source IP
     │               [4c] Notify analyst (email / Slack / webhook)
     │
     └─ BENIGN/UNKNOWN ▶ [5] TheHive: create low-priority alert, tag "review"
```

## Wire the webhook to Wazuh

1. In Shuffle, add the **Webhook** trigger to the workflow; copy its URL
   (`http://10.10.10.40:3001/api/v1/hooks/webhook_XXXX`).
2. In the Wazuh manager `ossec.conf`, add (see `stack/wazuh/README.md`):
   ```xml
   <integration>
     <name>shuffle</name>
     <hook_url>http://10.10.10.40:3001/api/v1/hooks/webhook_XXXX</hook_url>
     <level>7</level>
     <alert_format>json</alert_format>
   </integration>
   ```
3. Restart the manager. Now every level ≥ 7 alert flows into the workflow.

## App credentials to set in Shuffle

- **TheHive app**: URL `http://10.10.10.20:9000` + an API key from TheHive.
- **MISP app**: URL `https://10.10.10.30` + `MISP_AUTH_KEY` (self-signed → allow insecure).
- **Cortex app** (or call analyzers directly): URL `http://10.10.10.21:9001` + API key.

## Start small

Ship **[1] → [2 MISP only] → [4a create case]** first and prove it end-to-end with one
`bruteforce.sh` run. Add VirusTotal, the decision branch, and active response once the
basic enrichment-to-case path is reliable. That single working path already closes the
loop: **detect → alert → enrich → case**.
