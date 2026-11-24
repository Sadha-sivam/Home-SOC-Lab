# Telemetry layer

Telemetry quality caps detection quality. Native logs alone aren't enough — you need
Sysmon, audited command lines, auditd, and network metadata. Install these on each
host **before** enrolling the Wazuh agent.

| Host | Install | Then enroll agent |
|---|---|---|
| DC01, SRV01, WKS01, WKS02 (Windows) | `windows/install-telemetry.ps1` (as admin) — Sysmon + audit policy + PowerShell logging | Wazuh agent → manager `10.10.10.10` |
| Domain-wide (instead of per-host) | `windows/audit-policy.md` — push the same via GPO | — |
| LNX01 (Ubuntu) | `linux/install-telemetry.sh` (as root) — auditd + ruleset | Wazuh agent |
| Sensor (10.10.10.50) | `network/docker-compose.yml` — Suricata + Zeek on the SPAN port | Wazuh agent (own group) |

The Wazuh agent's **collection** config (which channels/logs to ship) is centralized in
`../stack/wazuh/shared-agent.conf` — you don't configure it per host.

## Order

1. Windows: run `install-telemetry.ps1` → reboot isn't required, but log off/on so
   PowerShell logging applies to new sessions.
2. Linux: run `install-telemetry.sh`.
3. Sensor: bring up Suricata/Zeek.
4. Everywhere: install the Wazuh agent (see `../stack/wazuh/README.md`).
5. Confirm agents are `active` in the Wazuh dashboard → Agents, and that events flow
   (search `data.win.system.channel: "Microsoft-Windows-Sysmon/Operational"`).

## Time sync — non-negotiable

Skewed clocks destroy correlation windows. Point every host at the same NTP source
(the firewall or DC). On Windows: `w32tm /config /manualpeerlist:10.10.20.10 /update`.
On Linux: `timedatectl set-ntp true` with the DC/firewall as the server.
