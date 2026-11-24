# 🛡️ Home SOC Lab

A complete, self-hosted **home cybersecurity lab** — the kind of setup a real Security
Operations Centre (SOC) uses to catch hackers, but small enough to run on one computer.

You attack it on purpose (safely, in an isolated network), watch it detect the attack,
and practice responding — the exact loop security analysts do at work. Everything here is
free and open-source.

---

## What this actually is (in plain English)

Think of it as **a security camera system for computers**:

- **Sensors** watch each machine and the network for suspicious activity.
- A **SIEM** (the brain, here it's *Wazuh*) collects everything and raises alarms using
  rules you can read and edit.
- A **case system** (*TheHive*) is where you investigate an alarm, like a detective's desk.
- A **threat-intel database** (*MISP*) tells you if an IP address or file is already known
  to be malicious.
- An **automation tool** (*Shuffle*) does the boring first steps for you automatically.

You then use **attack tools** to safely simulate hackers and confirm the alarms actually
go off — then improve the rules. That practice loop is the whole point.

> **Adapted and maintained by [Sadhasivam](https://github.com/Sadha-sivam)** as part of my
> cybersecurity GitHub portfolio. This is an adapted copy of the original
> [zeistoji/home-soc-lab](https://github.com/zeistoji/home-soc-lab) project; the original
> creator's work, attribution and MIT license are retained (see [License & use](#license--use)).

---

## ⚠️ One important thing to understand

This project has **two halves**:

1. **The software** (in the `stack/` folder) — runs in Docker with one command. ✅ Done for you.
2. **The lab machines** (Windows PCs, a network, attack tools) — you set these up on your
   own computer/VMs by following the step-by-step guides in the `docs/` folder.

So this repo gives you the finished software and complete instructions. It does **not**
magically create virtual machines — you build those by following `docs/build-order.md`.
That's normal: even in a real company, someone racks the servers by hand.

**Only ever attack machines you own inside this lab. Never point these tools at anything else.**

---

## What you need

- A computer with **16 GB RAM** free (32 GB+ if you want the full stack) and ~100 GB disk.
- **Docker Desktop** installed ([get it here](https://www.docker.com/products/docker-desktop/)).
- Windows with **PowerShell** (already on your PC). Mac/Linux work too with minor tweaks.

## ▶️ Get the software running (3 steps)

```powershell
# 1. Copy the settings file and open it to set passwords (any text editor)
cp .env.example .env

# 2. Start the SIEM (the core brain). First run downloads a few GB — be patient.
./soc.ps1 up core

# 3. Check it's alive
./soc.ps1 status
```

Then open **https://localhost** in your browser → log in with `admin` and the
`INDEXER_PASSWORD` from your `.env` file. That's your SOC dashboard.

Want the full toolkit (case system + threat intel + automation)? Run `./soc.ps1 up all`
instead (needs the extra RAM). To stop everything: `./soc.ps1 down all`.

> 🔐 **Before doing anything serious, change the default passwords** — see
> [`docs/hardening.md`](docs/hardening.md).

---

## What's inside

| Folder | What it's for | Start here |
|---|---|---|
| `stack/` | The software: SIEM, case system, threat intel, automation | run `./soc.ps1 up core` |
| `telemetry/` | Installers that make your Windows/Linux machines report activity | [telemetry/README.md](telemetry/README.md) |
| `detections/` | The detection rules — the "if you see X, raise an alarm" logic | [detections/README.md](detections/README.md) |
| `emulation/` | Safe fake-attacks to test that the alarms work | [emulation/README.md](emulation/README.md) |
| `response/` | Step-by-step guides for handling each type of alarm | [response/README.md](response/README.md) |
| `coverage/` | A visual map of which attacks you can detect | [coverage/README.md](coverage/README.md) |
| `docs/` | How to build the lab machines & network (the manual part) | **[docs/build-order.md](docs/build-order.md)** |

## 🗺️ Where to start

New to all this? Read them in this order:

1. **[docs/build-order.md](docs/build-order.md)** — the big-picture "do this, then this" plan.
2. **[docs/network-segmentation.md](docs/network-segmentation.md)** — how the lab network is laid out.
3. **[telemetry/README.md](telemetry/README.md)** — getting your machines to report in.
4. **[emulation/README.md](emulation/README.md)** — running your first safe attack.

---

## 📤 Push this to your GitHub

1. Go to **[github.com/new](https://github.com/new)**, name the repo (e.g. `home-soc-lab`),
   leave it empty (don't add a README/license — you already have them), click **Create**.
2. Copy the commands GitHub shows you, or use these:

```bash
git remote add origin https://github.com/Sadha-sivam/home-soc-lab.git
git branch -M main
git push -u origin main
```

Your `.env` file (with real passwords) is **automatically excluded** from GitHub by
`.gitignore`, so your secrets stay private. ✅

---

## For the technically curious

This lab is built on real detection-engineering principles: **detection-as-code** (rules
live in Git, mapped to [MITRE ATT&CK](https://attack.mitre.org/), validated by simulated
attacks) and the **emulate → detect → tune → measure** loop. The core is Wazuh; the full
stack adds TheHive + Cortex (cases), MISP (intel), and Shuffle (automation). Detection
rules are portable [Sigma](https://sigmahq.io/) plus Wazuh-native correlations. See each
folder's README for depth.

## License & use

For **educational and authorized security testing only**, on infrastructure you own.
See [LICENSE](LICENSE).

**Attribution:** This project is adapted from the original
[zeistoji/home-soc-lab](https://github.com/zeistoji/home-soc-lab). All original work remains
credited to its creator and is distributed under the original MIT license, with the original
copyright notice kept unchanged in [LICENSE](LICENSE). This adapted copy is maintained by
[Sadhasivam](https://github.com/Sadha-sivam).
