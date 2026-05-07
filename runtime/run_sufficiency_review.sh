#!/usr/bin/env bash
# run_sufficiency_review.sh
# Scans ~/kestrel-memory/knowledge/staged/ and reports sufficiency status.

set -euo pipefail

STAGED="$HOME/kestrel-memory/knowledge/staged"
RUNTIME="$HOME/kestrel-memory/runtime"
REPORT="$RUNTIME/sufficiency_review_$(date +%Y%m%d_%H%M%S).txt"

REQUIRED_MD_FIELDS=("CLASSIFICATION" "EPISTEMIC_LEVEL")
REQUIRED_JSON_FIELDS=("epistemic_level" "classification" "review_status" "confidence")

pass=0
warn=0
fail=0

json_has_field() {
  local file="$1" field="$2"
  CHECK_FILE="$file" CHECK_FIELD="$field" python3 -c '
import json,sys,os
try:
    d=json.load(open(os.environ["CHECK_FILE"]))
    sys.exit(0 if os.environ["CHECK_FIELD"] in d else 1)
except Exception:
    sys.exit(2)
' 2>/dev/null
}

json_get() {
  local file="$1" key="$2" default="$3"
  CHECK_FILE="$file" CHECK_KEY="$key" CHECK_DEFAULT="$default" python3 -c '
import json,sys,os
try:
    d=json.load(open(os.environ["CHECK_FILE"]))
    print(d.get(os.environ["CHECK_KEY"], os.environ["CHECK_DEFAULT"]))
except Exception:
    print(os.environ["CHECK_DEFAULT"])
' 2>/dev/null
}

run_review() {
  echo "=== Sufficiency Review ==="
  echo "Run at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Staged dir: $STAGED"
  echo ""

  echo "## JSON entries"
  for f in "$STAGED"/*.json; do
    [ -f "$f" ] || continue
    fname="$(basename "$f")"
    missing=()
    for field in "${REQUIRED_JSON_FIELDS[@]}"; do
      json_has_field "$f" "$field" || missing+=("$field")
    done
    review=$(json_get "$f" "review_status" "MISSING")
    el=$(json_get "$f" "epistemic_level" "MISSING")
    if [ ${#missing[@]} -eq 0 ]; then
      echo "  [PASS] $fname  review_status=$review  epistemic_level=$el"
      ((pass++)) || true
    else
      echo "  [FAIL] $fname  missing: ${missing[*]}"
      ((fail++)) || true
    fi
  done

  echo ""
  echo "## Markdown entries"
  for f in "$STAGED"/*.md; do
    [ -f "$f" ] || continue
    fname="$(basename "$f")"
    missing=()
    for field in "${REQUIRED_MD_FIELDS[@]}"; do
      grep -qi "^- ${field}:" "$f" 2>/dev/null || missing+=("$field")
    done
    if [ ${#missing[@]} -gt 0 ]; then
      echo "  [FAIL] $fname  missing: ${missing[*]}"
      ((fail++)) || true
    else
      el=$(grep -i "EPISTEMIC_LEVEL" "$f" | head -1 | sed 's/.*EPISTEMIC_LEVEL:[ `]*//' | tr -d '`' | xargs)
      cl=$(grep -i "^- CLASSIFICATION:" "$f" | head -1 | sed 's/.*CLASSIFICATION:[ `]*//' | tr -d '`' | xargs)
      echo "  [PASS] $fname  classification=${cl}  epistemic_level=${el}"
      ((pass++)) || true
    fi
  done

  echo ""
  echo "## Summary"
  echo "  PASS: $pass"
  echo "  WARN: $warn"
  echo "  FAIL: $fail"
  echo "  Total: $((pass + warn + fail))"
  echo ""
  if [ $fail -eq 0 ]; then
    echo "STATUS: SUFFICIENT — all staged items meet field requirements."
  else
    echo "STATUS: INSUFFICIENT — $fail item(s) require attention before promotion."
  fi
}

run_review | tee "$REPORT"
echo ""
echo "Report saved: $REPORT"
