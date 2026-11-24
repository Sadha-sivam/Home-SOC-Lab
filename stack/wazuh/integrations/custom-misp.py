#!/usr/bin/env python3
"""
Wazuh -> MISP enrichment integration.

Wazuh runs this per alert (configured via an <integration> block, see
stack/wazuh/README.md). It pulls indicators out of the alert (IPs, DNS queries,
file hashes, URLs), asks MISP whether any are known-bad, and if so writes an
event back into Wazuh's analysis socket tagged {"integration":"misp"} so
local rule 100600 fires with the MISP context attached.

Invocation by Wazuh:  custom-misp <alert_file> <misp_api_key> <misp_base_url>
Self-check:           custom-misp.py --selftest   (no network; tests extraction)
"""
import json
import sys
import ipaddress
import socket
import re

# ── indicator extraction ─────────────────────────────────────────────────────
_HASH_RE = re.compile(r"\b([a-fA-F0-9]{32}|[a-fA-F0-9]{40}|[a-fA-F0-9]{64})\b")


def _is_public_ip(value):
    try:
        ip = ipaddress.ip_address(value)
        return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast)
    except ValueError:
        return False


def extract_indicators(alert):
    """Return a de-duplicated list of (type, value) IOCs worth checking in MISP.

    Kept deliberately small: the high-signal fields Sysmon/Suricata/auditd give us.
    Private/loopback IPs are dropped — MISP holds internet-facing badness.
    """
    data = alert.get("data", {})
    win = data.get("win", {}).get("eventdata", {})
    iocs = set()

    # network endpoints
    for v in (data.get("srcip"), data.get("dstip"),
              win.get("destinationIp"), win.get("sourceIp"),
              data.get("dest_ip"), data.get("src_ip")):
        if v and _is_public_ip(v):
            iocs.add(("ip-dst", v))

    # DNS queries / hostnames
    for v in (win.get("queryName"), data.get("dns", {}).get("rrname")
              if isinstance(data.get("dns"), dict) else None):
        if v:
            iocs.add(("domain", v.rstrip(".")))

    # file hashes (Sysmon EID1/11 "hashes" field, or Suricata fileinfo)
    hashfields = [win.get("hashes"), win.get("hash")]
    fileinfo = data.get("fileinfo") if isinstance(data.get("fileinfo"), dict) else {}
    hashfields += [fileinfo.get("md5"), fileinfo.get("sha1"), fileinfo.get("sha256")]
    for hf in hashfields:
        if not hf:
            continue
        for m in _HASH_RE.findall(str(hf)):
            iocs.add(("hash", m.lower()))

    # URLs (Suricata http, or command lines with http)
    http = data.get("http") if isinstance(data.get("http"), dict) else {}
    if http.get("hostname") and http.get("url"):
        iocs.add(("url", f"{http['hostname']}{http['url']}"))

    return sorted(iocs)


# ── MISP query + re-injection (only reached in live mode) ─────────────────────
def query_misp(base_url, api_key, ioc_type, value):
    import urllib.request
    import ssl
    type_map = {"ip-dst": "ip-dst", "domain": "domain", "hash": None, "url": "url"}
    search = {"returnFormat": "json", "value": value, "limit": 1}
    if type_map.get(ioc_type):
        search["type"] = type_map[ioc_type]
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/attributes/restSearch",
        data=json.dumps(search).encode(),
        headers={"Authorization": api_key, "Accept": "application/json",
                 "Content-Type": "application/json"},
        method="POST",
    )
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # lab MISP uses a self-signed cert
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        body = json.loads(resp.read().decode())
    attrs = body.get("response", {}).get("Attribute", [])
    return attrs[0] if attrs else None


def send_to_wazuh(payload):
    sock_addr = "/var/ossec/queue/sockets/queue"
    msg = f'1:misp:{json.dumps(payload)}'
    s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    s.connect(sock_addr)
    s.send(msg.encode())
    s.close()


def main():
    with open(sys.argv[1]) as f:
        alert = json.load(f)
    api_key = sys.argv[2] if len(sys.argv) > 2 else ""
    base_url = sys.argv[3] if len(sys.argv) > 3 else ""
    if not api_key or not base_url:
        return  # not configured; nothing to enrich

    for ioc_type, value in extract_indicators(alert):
        try:
            hit = query_misp(base_url, api_key, ioc_type, value)
        except Exception:
            continue  # MISP down / timeout — fail open, don't drop the pipeline
        if hit:
            send_to_wazuh({
                "integration": "misp",
                "misp": {
                    "value": value,
                    "type": ioc_type,
                    "category": hit.get("category", "unknown"),
                    "event_id": hit.get("event_id"),
                    "comment": hit.get("comment", ""),
                    "source_rule_id": alert.get("rule", {}).get("id"),
                    "agent": alert.get("agent", {}).get("name"),
                },
            })


def _selftest():
    sample = {
        "rule": {"id": "100230"},
        "agent": {"name": "WKS01"},
        "data": {"win": {"eventdata": {
            "destinationIp": "45.83.192.44",
            "queryName": "evil.example.com.",
            "sourceIp": "10.10.20.101",
            "hashes": "MD5=44d88612fea8a8f36de82e1278abb02f,SHA256="
                      "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f",
        }}},
    }
    got = extract_indicators(sample)
    assert ("ip-dst", "45.83.192.44") in got, got            # public IP kept
    assert ("ip-dst", "10.10.20.101") not in got, got        # private IP dropped
    assert ("domain", "evil.example.com") in got, got        # trailing dot stripped
    assert ("hash", "44d88612fea8a8f36de82e1278abb02f") in got, got
    assert ("hash", "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f") in got, got
    print("selftest OK:", len(got), "indicators")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        _selftest()
    else:
        main()
