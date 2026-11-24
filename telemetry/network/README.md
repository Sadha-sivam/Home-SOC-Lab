# Network sensors — Suricata + Zeek

Both run on the sensor VM (`10.10.10.50`), which sits on the firewall's **SPAN/mirror
port** so it passively sees Enterprise↔Attacker traffic. They write to host paths the
Wazuh agent on this box tails.

## Prereqs on the sensor

```bash
sudo mkdir -p /var/log/suricata /opt/zeek/logs
# find your mirror interface (the one receiving mirrored traffic, no IP needed)
ip -br link
```

## Run

```bash
SPAN_IFACE=ens19 docker compose up -d      # replace ens19 with your mirror iface
docker compose logs -f suricata            # confirm it's sniffing + rules loaded
```

- **Suricata** → `/var/log/suricata/eve.json` (EVE JSON: alerts, flow, dns, http, tls).
  ET Open ruleset is managed inside the image; `suricata/custom.rules` is loaded on top
  and gives you deterministic lab alerts (scan, SMB spray, EXE-over-HTTP, DNS tunneling).
- **Zeek** → `/opt/zeek/logs/current/*.log` as JSON (conn, dns, http, ssl, x509, files).
  Great for hunting and behavioural detection.

## Into the SIEM

The Wazuh agent on the sensor ships both via `stack/wazuh/shared-agent.conf`
(`/var/log/suricata/eve.json` as `json`, Zeek `conn.log`/`dns.log` as `json`). Wazuh's
built-in Suricata decoder parses EVE; custom rule `100500` promotes severity-1 Suricata
alerts to a case-worthy level. Put the sensor in its own Wazuh **group** so only it gets
the Suricata/Zeek `localfile` blocks.

## Validate

From the attacker VLAN, run a scan at the enterprise VLAN and watch `eve.json`:

```bash
nmap -sS 10.10.20.0/24        # should trip SOC-LAB sid:9000001 within seconds
tail -f /var/log/suricata/eve.json | grep --line-buffered SOC-LAB
```
