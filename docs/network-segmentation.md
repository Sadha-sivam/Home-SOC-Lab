# Network segmentation & firewall policy (§2)

Segment like a real environment. Flat networks teach bad habits and hide lateral-movement
telemetry. This is the reference topology the rest of the repo's IPs assume.

```
                          ┌──────────────────────────────┐
                          │   Firewall / Router           │
                          │   pfSense or OPNsense          │
                          │   (inter-VLAN routing + rules) │
                          └───────┬───────┬───────┬────────┘
                                  │       │       │
        ┌─────────────────────────┘       │       └─────────────────────────┐
        │ VLAN 10 — SOC / Management       │ VLAN 20 — Enterprise (victims)  │
        │ 10.10.10.0/24                    │ 10.10.20.0/24                   │
        │  Wazuh (SIEM)   10.10.10.10      │  DC01 (AD/DNS) 10.10.20.10      │
        │  TheHive        10.10.10.20      │  SRV01 (file)  10.10.20.20      │
        │  Cortex         10.10.10.21      │  WKS01 (Win11) 10.10.20.101     │
        │  MISP           10.10.10.30      │  WKS02 (Win11) 10.10.20.102     │
        │  Shuffle SOAR   10.10.10.40      │  LNX01 (Ubuntu)10.10.20.50      │
        │  Net sensor     10.10.10.50 ─────┼── SPAN/mirror ◄─────────────────┤
        └──────────────────────────────────┴─────────────────────────────────┘
                                  │
        ┌─────────────────────────┘
        │ VLAN 99 — Attacker / Red (isolated egress)
        │ 10.10.99.0/24
        │  Kali        10.10.99.10
        │  Caldera C2  10.10.99.20
        │  GoPhish     10.10.99.30
        └────────────────────────────────────────────
```

## Firewall rules (the segmentation IS a control)

| From ↓ / To → | SOC (10) | Enterprise (20) | Attacker (99) | Internet |
|---|---|---|---|---|
| **SOC (10)** | allow | allow (mgmt/agent) | deny | allow (updates) |
| **Enterprise (20)** | allow **only** agent/log ports to 10.10.10.10 (1514/1515/tcp, 55000) | allow (internal) | — | allow (realistic beaconing) |
| **Attacker (99)** | **deny** (must not touch SOC infra) | **allow** (that's the point) | allow | constrained / none unless controlled C2 exercise |

Enforce, specifically:
- **SOC VLAN**: reachable only from itself and admin. Block inbound from Enterprise/Attacker
  except the agent/log ports to the Wazuh manager.
- **Enterprise VLAN**: normal internal comms; internet allowed for realistic beaconing.
- **Attacker VLAN**: can reach Enterprise; firewalled from directly touching SOC infra;
  constrained/no internet unless you're running a controlled C2-over-internet exercise.
- **Sensor**: hangs off a **SPAN/mirror port** (or inline tap) so it passively sees
  Enterprise↔Attacker traffic. It needs no routable exposure to do its job.

## Hypervisor

- **Proxmox VE** (recommended, dedicated box): free, VLAN-aware Linux bridges, snapshots,
  templates, LXC + KVM.
- **ESXi free / XCP-ng**: solid type-1 alternatives.
- **VMware Workstation / VirtualBox** (laptop-scale): use host-only + internal networks to
  emulate the VLANs.

Sizing: **min** 32 GB / 8 core / 500 GB SSD (Wazuh + DC + 2 endpoints + Kali). **Comfortable**
64 GB / NVMe / ~1 TB for the full stack incl. MISP/TheHive/Shuffle.

> Snapshot everything before each attack run. "Detonate → inspect → roll back" is the loop.
