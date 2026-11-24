# Wazuh SIEM (single-node)

Indexer + manager + dashboard, mirroring the official `wazuh-docker` single-node
deployment, overlaid with our detection-as-code. This is the core of the lab —
stand it up first (`../../soc.ps1 up core`).

## Files

| Path | Role |
|---|---|
| `docker-compose.yml` | the three services + volumes |
| `generate-indexer-certs.yml` | one-shot TLS cert generator |
| `config/certs.yml` | cert subjects (indexer/manager/dashboard) |
| `config/wazuh_indexer/` | opensearch.yml + internal_users.yml (password hashes) |
| `config/wazuh_dashboard/` | dashboard + manager-API connection config |
| `custom-rules/local_rules.xml` | **our correlation rules** (brute-force→success, LSASS, etc.) |
| `custom-decoders/local_decoder.xml` | custom decoders (mostly built-ins suffice) |
| `shared-agent.conf` | centralized agent collection config (Sysmon/PowerShell/auditd/Suricata) |
| `integrations/custom-misp*` | Wazuh→MISP IOC enrichment |

## Bring-up

```powershell
../../soc.ps1 certs        # once — writes config/wazuh_indexer_ssl_certs/
../../soc.ps1 up core
```

If the indexer crash-loops on boot, the host mmap limit is too low:

```bash
wsl -d docker-desktop sysctl -w vm.max_map_count=262144
```

## Push the centralized agent config

Agents only collect Sysmon/PowerShell/auditd once the manager serves this group config:

```bash
docker compose cp shared-agent.conf wazuh.manager:/var/ossec/etc/shared/default/agent.conf
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

## Enable SOAR + threat-intel integrations

These live in the manager's `ossec.conf`. Edit it in place, then restart:

```bash
docker compose exec wazuh.manager sh -c 'vi /var/ossec/etc/ossec.conf'
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

Add inside `<ossec_config>`:

```xml
<!-- SOAR: forward level>=7 alerts to a Shuffle webhook (§9) -->
<integration>
  <name>shuffle</name>
  <hook_url>http://10.10.10.40:3001/api/v1/hooks/webhook_REPLACE_ME</hook_url>
  <level>7</level>
  <alert_format>json</alert_format>
</integration>

<!-- Threat intel: enrich these event groups against MISP (§8) -->
<integration>
  <name>custom-misp</name>
  <api_key>PASTE_MISP_AUTH_KEY</api_key>
  <hook_url>https://10.10.10.30</hook_url>
  <group>sysmon_event1,sysmon_event3,sysmon_event_22,ids,suricata</group>
  <alert_format>json</alert_format>
</integration>
```

Then install the MISP integration script into the manager:

```bash
docker compose cp integrations/custom-misp     wazuh.manager:/var/ossec/integrations/custom-misp
docker compose cp integrations/custom-misp.py  wazuh.manager:/var/ossec/integrations/custom-misp.py
docker compose exec wazuh.manager chmod 750 /var/ossec/integrations/custom-misp /var/ossec/integrations/custom-misp.py
docker compose exec wazuh.manager chown root:wazuh /var/ossec/integrations/custom-misp /var/ossec/integrations/custom-misp.py
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

The Shuffle webhook (built into Wazuh) needs no script — just the workflow's webhook
URL from Shuffle (`stack/shuffle/`). The MISP `custom-misp` script is what powers
local rule `100600`.

## Enroll an agent (from a victim VM)

Install the Wazuh agent, point it at the manager IP, enroll:

```powershell
# Windows victim
msiexec /i wazuh-agent.msi /q WAZUH_MANAGER="10.10.10.10" WAZUH_AGENT_GROUP="default"
net start WazuhSvc
```
```bash
# Linux victim
WAZUH_MANAGER="10.10.10.10" apt install ./wazuh-agent.deb && systemctl enable --now wazuh-agent
```

See `../../telemetry/README.md` for what to install on each host first (Sysmon, audit policy, auditd).

## Validate the custom rules

Use the log tester to confirm a rule fires without waiting for a real event:

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
# paste a sample Sysmon EID 1 JSON line and confirm it hits rule 100220/100230/etc.
```

Or just run the emulation (`../../emulation/`) and watch the alerts.

> Reconstruction note: these configs mirror the upstream single-node deployment.
> If a future Wazuh release changes a config path, diff against the current
> `wazuh/wazuh-docker` single-node repo at the tag matching `WAZUH_VERSION`.
