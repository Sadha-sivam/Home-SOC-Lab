#!/usr/bin/env bash
# Install auditd + load the SOC-lab ruleset on an Ubuntu/Debian victim.
# Run as root:  sudo ./install-telemetry.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== auditd =="
apt-get update -qq
apt-get install -y auditd audispd-plugins

echo "== loading ruleset =="
install -m 640 "$HERE/audit.rules" /etc/audit/rules.d/soc-lab.rules
augenrules --load
systemctl enable --now auditd

echo "== verify =="
auditctl -l | sed -n '1,10p'
echo "auditd active: $(systemctl is-active auditd)"
echo
echo "auth.log / syslog / audit.log are collected by the Wazuh agent"
echo "(see ../../stack/wazuh/shared-agent.conf). Install the agent next:"
echo "  WAZUH_MANAGER=10.10.10.10 apt install ./wazuh-agent.deb && systemctl enable --now wazuh-agent"
