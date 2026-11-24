# Coverage & metrics

- `attack-navigator-layer.json` — import at
  [mitre-attack.github.io/attack-navigator](https://mitre-attack.github.io/attack-navigator/)
  (Open Existing Layer → Upload). Green = validated & firing, yellow = partial. This is
  the coverage matrix a SOC manager reports on — versioned next to the rules that produce it.
- `kpi-queries.md` — MTTD/MTTR, TP/FP per rule, coverage %, and the operational dashboard
  panels to build in Wazuh + TheHive.

Update the layer in the **same commit** as any new detection. Use **DeTT&CT** for a
data-source-driven "what could I detect" view to find blind spots to close next.
