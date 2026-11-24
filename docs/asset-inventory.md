# Asset inventory

Single source of truth for lab IPs/roles. The repo's configs, rules, and emulation
scripts assume these addresses — change here and grep the repo if you renumber.

| Host | VLAN | IP | OS | Role | Telemetry | Wazuh agent |
|---|---|---|---|---|---|---|
| Wazuh | 10 SOC | 10.10.10.10 | Docker host | SIEM (indexer+manager+dashboard) | — | manager |
| TheHive | 10 SOC | 10.10.10.20 | Docker host | Case management | — | — |
| Cortex | 10 SOC | 10.10.10.21 | Docker host | Analyzers/responders | — | — |
| MISP | 10 SOC | 10.10.10.30 | Docker host | Threat intel | — | — |
| Shuffle | 10 SOC | 10.10.10.40 | Docker host | SOAR | — | — |
| Sensor | 10 SOC | 10.10.10.50 | Ubuntu | Suricata + Zeek (SPAN) | Suricata/Zeek | yes (own group) |
| DC01 | 20 Ent | 10.10.20.10 | Win Server | AD / DNS | Sysmon + Security + PS | yes |
| SRV01 | 20 Ent | 10.10.20.20 | Win Server | File server | Sysmon + Security + PS | yes |
| WKS01 | 20 Ent | 10.10.20.101 | Win 11 | Workstation (primary victim) | Sysmon + Security + PS | yes |
| WKS02 | 20 Ent | 10.10.20.102 | Win 11 | Workstation | Sysmon + Security + PS | yes |
| LNX01 | 20 Ent | 10.10.20.50 | Ubuntu | Linux victim | auditd + auth.log | yes |
| Kali | 99 Red | 10.10.99.10 | Kali | Attacker | — | — |
| Caldera | 99 Red | 10.10.99.20 | Ubuntu | C2 | — | — |
| GoPhish | 99 Red | 10.10.99.30 | Ubuntu | Phishing | — | — |

## Service ports (SOC VLAN)
| Service | Port |
|---|---|
| Wazuh dashboard | 443 |
| Wazuh manager: agents / enroll / API | 1514, 1515, 55000 |
| TheHive | 9000 |
| Cortex | 9001 |
| MISP | 8443 (https), 8080 (http) |
| Shuffle | 3001 |
