# MISP feeds — turning MISP into a live IOC source

The free feeds below cover most home-lab threat intel. Enable them in
**Sync Actions → Feeds**, then select and **Fetch and store all feed data**
(schedule it to run daily via **Administration → Scheduled Tasks**).

| Feed | Provider | Content |
|---|---|---|
| CIRCL OSINT Feed | CIRCL | curated events, broad |
| URLhaus | abuse.ch | malware distribution URLs |
| Feodo Tracker | abuse.ch | botnet C2 IPs (Emotet/Dridex/etc.) |
| ThreatFox | abuse.ch | IOCs (IP/domain/hash) with malware tags |
| blocklist.de | blocklist.de | brute-force / attacking IPs |

These are shipped as default feeds in MISP — you usually just toggle them on. If a
feed is missing, add it via **Feeds → Add Feed** with the provider's URL and format
(`misp` or `freetext`).

## Closing the loop

- **Ingest:** feeds above keep MISP's IOC set current.
- **Match:** Wazuh's `custom-misp` integration (see `../wazuh/README.md`) checks every
  relevant alert's IPs/domains/hashes against MISP → fires local rule `100600`.
- **Enrich:** Cortex's MISP analyzer gives TheHive observables instant MISP context.
- **Produce:** IOCs you extract from your own emulations go back into MISP as events,
  so the next detonation is matched against your own intel.

## After enabling feeds, wire the key

1. **Administration → List Auth Keys → Add authentication key** (comment: `wazuh`).
2. Paste the key into:
   - `.env` → `MISP_AUTH_KEY`
   - the Wazuh `<integration><name>custom-misp>` block (`../wazuh/README.md`)
   - TheHive `application.conf` (`misp` block) and Cortex's MISP analyzer config.
