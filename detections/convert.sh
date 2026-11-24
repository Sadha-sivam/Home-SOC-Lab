#!/usr/bin/env bash
# Convert the Sigma source-of-truth to backend queries. Sigma is portable; this
# proves it and produces ready-to-paste queries for Elastic (Option A SIEMs) and a
# generic reference. The Wazuh-native correlation rules are hand-authored from the
# same Sigma (see ../stack/wazuh/custom-rules/) because Sigma can't express the
# stateful "X then Y" composites.
#
#   ./convert.sh            # convert every rule -> build/
#   ./convert.sh validate   # just lint/validate the rules
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"
RULES="$HERE/sigma"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1"; MISSING=1; }; }
MISSING=0; need sigma; [ "${MISSING:-0}" = 1 ] && {
  echo; echo "Install the toolchain first:"
  echo "  pip install sigma-cli pysigma-backend-elasticsearch pysigma-pipeline-windows"
  exit 1
}

if [ "${1:-}" = "validate" ]; then
  echo "== validating Sigma rules =="
  sigma check "$RULES"
  exit $?
fi

mkdir -p "$OUT"
echo "== Sigma -> Elasticsearch (Lucene, ECS Windows mapping) =="
# Convert Windows rules with the ECS windows pipeline; Linux rules without it.
sigma convert -t elasticsearch -p ecs_windows "$RULES/windows" \
  > "$OUT/windows_elastic.txt" 2>/dev/null || \
  echo "  (per-rule conversion — some count-correlation rules need the correlations backend)"

sigma convert -t elasticsearch "$RULES/linux" \
  > "$OUT/linux_elastic.txt" 2>/dev/null || true

echo "Wrote:"
ls -1 "$OUT"
echo
echo "Paste windows_elastic.txt queries into Elastic Security detection rules, or use"
echo "them as Discover/Lens searches. For Wazuh, the equivalents already live as XML in"
echo "../stack/wazuh/custom-rules/local_rules.xml — keep the two in sync via git."
