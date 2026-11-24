# Phishing-with-execution emulation (GoPhish) — §6.4

Exercises the full **initial-access → execution** chain and validates rule `100220`
(`winword.exe → powershell.exe`) plus GoPhish's own click/open tracking. Runs entirely
inside the lab. **Never point GoPhish at anything you don't own.**

## 1. Stand up GoPhish (attacker VLAN, 10.10.99.30)

```bash
docker run -d --name gophish -p 3333:3333 -p 8080:80 gophish/gophish
docker logs gophish | grep -i "please login"   # grab the generated admin password
```

Admin UI: `https://10.10.99.30:3333`. Build the four pieces:

- **Sending Profile** — an SMTP relay you control on the lab (e.g. a MailHog/Postfix on
  the attacker VLAN). No external mail.
- **Landing Page** — clone a simple internal-looking login; enable "Capture Submitted
  Data" to demonstrate credential harvesting telemetry.
- **Email Template** — lure with the macro doc (below) attached.
- **Campaign** — target your lab users (`user1..3@lab.local`), launch.

## 2. The benign "malicious" attachment

Create a Word doc with this macro. It is deliberately harmless — it only spawns
PowerShell that drops a marker file — but it produces the exact `winword.exe →
powershell.exe` parent/child that rule `100220` and the Sigma rule
`proc_office_spawning_interpreter` detect.

```vba
Sub AutoOpen()
    ' Benign detonation marker — NO payload. Generates the Office->PowerShell telemetry.
    Dim cmd As String
    cmd = "powershell.exe -NoProfile -Command ""Set-Content $env:TEMP\phish_marker.txt 'detonated'"""
    Shell cmd, vbHide
End Sub
```

Save as `.docm` (macro-enabled). When a lab user opens it and enables macros:

- GoPhish records the open/click.
- Sysmon EID 1 fires on `winword.exe → powershell.exe` → Wazuh rule `100220`.
- If you extend the macro to reach out (a lab-internal URL only), Sysmon EID 3/22 add
  the callback/DNS leg.

## 3. Validate

Wazuh dashboard → filter `rule.id: 100220`. You should see the process-ancestry alert
with the full command line. Then run the phishing runbook
(`../../response/runbooks/phishing.md`) end-to-end as a TheHive case.
