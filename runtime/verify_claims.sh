#!/usr/bin/env bash
# verify_claims.sh v2
# Two-pass claim verification with witness/discovery separation.
#
# Discovery (non-voting): OpenAlex, Semantic Scholar
# Witness (voting):       arXiv API, Crossref, INSPIRE-HEP, NIST/CSRC
#
# Pass 1: claim            → reinforced_claim   (≥1 distinct witness)
# Pass 2: reinforced_claim → fact_candidate     (≥2 distinct witness sources)
#
# Same-run double-promotion is disallowed: Pass 2 skips items whose
# last_verified_at matches the current run timestamp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/sources.sh"

STAGED="$HOME/kestrel-memory/knowledge/staged"
RUNTIME="$HOME/kestrel-memory/runtime"
LOG="$RUNTIME/verify_claims.log"
PROMOTE_SCRIPT="$RUNTIME/run_promotion_queue.sh"

DRY_RUN=false
SHADOW_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --shadow-dir) SHADOW_DIR="$2"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -n "$SHADOW_DIR" ]; then
  STAGED="$SHADOW_DIR"
  log_prefix="[SHADOW]"
else
  log_prefix=""
fi

RUN_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")]${log_prefix} $*" | tee -a "$LOG"; }

log "════════════════════════════════════════════════════════"
log "verify_claims.sh v2 started (dry_run=${DRY_RUN})"
log "Staged dir : $STAGED"
log "Run ts     : $RUN_TS"
log "════════════════════════════════════════════════════════"

# ── source tallies ────────────────────────────────────────────────────────────
declare -A SRC_HITS SRC_ATTEMPTS
for src in arxiv crossref inspire nist; do
  SRC_HITS[$src]=0
  SRC_ATTEMPTS[$src]=0
done

# ── query construction ────────────────────────────────────────────────────────
build_query() {
  local file="$1"
  python3 -c "
import json, sys, re
try:
    d = json.load(open(sys.argv[1]))
    q = d.get('title') or ''
    if not q:
        raw = d.get('claim_text') or d.get('content') or d.get('text') or ''
        q = re.split(r'[.!?]', raw.strip())[0][:200]
    q = q.strip()
    if q:
        print(q)
except:
    pass
" "$file" 2>/dev/null
}

# ── run all witnesses for a query ─────────────────────────────────────────────
# Prints matched {source,url,text} JSON lines to stdout.
run_witnesses() {
  local query="$1"
  local combined="[]"

  for src in arxiv crossref inspire nist; do
    SRC_ATTEMPTS[$src]=$((${SRC_ATTEMPTS[$src]} + 1))
    local hits
    case "$src" in
      arxiv)    hits=$(witness_arxiv   "$query" || echo "[]") ;;
      crossref) hits=$(witness_crossref "$query" || echo "[]") ;;
      inspire)  hits=$(witness_inspire  "$query" || echo "[]") ;;
      nist)     hits=$(witness_nist     "$query" || echo "[]") ;;
    esac
    hits="${hits:-[]}"

    local count
    count=$(echo "$hits" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    log "    [$src] $count result(s)"

    local matched=0
    while IFS= read -r entry; do
      local text
      text=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('text',''))" 2>/dev/null)
      if match_corroboration "$query" "$text"; then
        matched=1
        echo "$entry"
        SRC_HITS[$src]=$((${SRC_HITS[$src]} + 1))
      fi
    done < <(echo "$hits" | python3 -c "
import json, sys
hits = json.load(sys.stdin)
for h in hits:
    print(json.dumps(h))
" 2>/dev/null)
    [ $matched -eq 0 ] && log "    [$src] no corroborating match"
  done
}

# ── mutate item on successful promotion ──────────────────────────────────────
promote_item() {
  local file="$1" new_level="$2"
  shift 2
  local sources_json="$*"

  if $DRY_RUN; then
    log "  [DRY-RUN] would promote to $new_level — sources: $sources_json"
    return 0
  fi

  local tmp="${file}.tmp"
  FILE="$file" LEVEL="$new_level" SOURCES="$sources_json" TS="$RUN_TS" \
  python3 - << 'PYEOF'
import json, os, sys
path = os.environ["FILE"]
new_level = os.environ["LEVEL"]
sources = json.loads(os.environ["SOURCES"])
ts = os.environ["TS"]
with open(path) as f:
    d = json.load(f)
d["epistemic_level"] = new_level
d["verification_sources"] = d.get("verification_sources", []) + sources
d["last_verified_at"] = ts
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
os.rename(tmp, path)
PYEOF
}

# ══════════════════════════════════════════════════════════════════════════════
# PASS 1: claim → reinforced_claim (≥1 distinct witness)
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "── PASS 1: claim → reinforced_claim ──────────────────────"

pass1_total=0
pass1_promoted=0

for f in "$STAGED"/*.json; do
  [[ -f "$f" ]] || continue
  level=$(python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get('epistemic_level',''))
except: print('')
" "$f")
  [[ "$level" == "claim" ]] || continue
  ((pass1_total++)) || true

  fname=$(basename "$f")
  query=$(build_query "$f")
  if [[ -z "$query" ]]; then
    log ""
    log "FILE: $fname — SKIP: no query could be built"
    continue
  fi

  log ""
  log "FILE: $fname"
  log "  Query: $query"
  log "  Discovery:"

  # Discovery phase (non-voting — logged only)
  local_candidates=$(query_openalex "$query" 2>/dev/null || true; query_semantic_scholar "$query" 2>/dev/null || true)
  candidate_count=$(echo "$local_candidates" | grep -c . 2>/dev/null || echo 0)
  log "  Discovery candidates: $candidate_count URL(s)"

  log "  Witnesses:"
  matched_sources=()
  while IFS= read -r entry; do
    src=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('source',''))" 2>/dev/null)
    url=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('url',''))" 2>/dev/null)
    log "    MATCH [$src]: $url"
    matched_sources+=("$entry")
  done < <(run_witnesses "$query")

  distinct_sources=$(printf '%s\n' "${matched_sources[@]}" | \
    python3 -c "
import json, sys
names = set()
for line in sys.stdin:
    line = line.strip()
    if line:
        try: names.add(json.loads(line).get('source',''))
        except: pass
print(len(names))
" 2>/dev/null || echo 0)

  log "  Distinct witness sources: $distinct_sources"

  if [[ ${#matched_sources[@]} -ge 1 ]]; then
    sources_json=$(printf '%s\n' "${matched_sources[@]}" | python3 -c "
import json, sys
items = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try:
            d = json.loads(line)
            items.append({'source': d.get('source',''), 'url': d.get('url',''), 'fetched_at': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'})
        except: pass
print(json.dumps(items))
" 2>/dev/null)
    promote_item "$f" "reinforced_claim" "$sources_json"
    log "  PROMOTED: claim → reinforced_claim"
    ((pass1_promoted++)) || true
  else
    log "  NOT_PROMOTED: no corroborating witness"
  fi
done

log ""
log "Pass 1 source tallies:"
for src in arxiv crossref inspire nist; do
  log "  $src: ${SRC_HITS[$src]} hits / ${SRC_ATTEMPTS[$src]} attempts"
done
log "Pass 1 complete: ${pass1_promoted}/${pass1_total} promoted to reinforced_claim"

# Reset tallies for pass 2
for src in arxiv crossref inspire nist; do
  SRC_HITS[$src]=0
  SRC_ATTEMPTS[$src]=0
done

# ══════════════════════════════════════════════════════════════════════════════
# PASS 2: reinforced_claim → fact_candidate (≥2 DISTINCT witness sources)
# Items promoted in this same run (last_verified_at == RUN_TS) are SKIPPED.
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "── PASS 2: reinforced_claim → fact_candidate ─────────────"

pass2_total=0
pass2_promoted=0

for f in "$STAGED"/*.json; do
  [[ -f "$f" ]] || continue
  read -r level last_verified < <(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('epistemic_level',''), d.get('last_verified_at',''))
except: print('', '')
" "$f")

  [[ "$level" == "reinforced_claim" ]] || continue

  # Same-run gating: skip if promoted in this run
  if [[ "$last_verified" == "$RUN_TS" ]]; then
    log ""
    log "FILE: $(basename $f) — SKIP: promoted in this run (same-run gating)"
    continue
  fi

  ((pass2_total++)) || true

  fname=$(basename "$f")
  query=$(build_query "$f")
  if [[ -z "$query" ]]; then
    log ""
    log "FILE: $fname — SKIP: no query could be built"
    continue
  fi

  # Check existing distinct sources from prior verifications
  existing_sources=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    names = {e.get('source','') for e in d.get('verification_sources',[]) if isinstance(e,dict)}
    print(len(names))
except: print(0)
" "$f" 2>/dev/null || echo 0)

  log ""
  log "FILE: $fname"
  log "  Query: $query"
  log "  Existing distinct sources: $existing_sources"

  log "  Discovery:"
  local_candidates=$(query_openalex "$query"; query_semantic_scholar "$query")
  candidate_count=$(echo "$local_candidates" | grep -c . 2>/dev/null || echo 0)
  log "  Discovery candidates: $candidate_count URL(s)"

  log "  Witnesses:"
  matched_sources=()
  while IFS= read -r entry; do
    src=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('source',''))" 2>/dev/null)
    url=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('url',''))" 2>/dev/null)
    log "    MATCH [$src]: $url"
    matched_sources+=("$entry")
  done < <(run_witnesses "$query")

  # Count distinct sources across existing + new hits
  all_source_names=$(python3 -c "
import json, sys
try:
    d = json.load(open('$f'))
    names = {e.get('source','') for e in d.get('verification_sources',[]) if isinstance(e,dict)}
    print('\n'.join(names))
except: pass
" 2>/dev/null)
  for entry in "${matched_sources[@]}"; do
    src=$(echo "$entry" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('source',''))" 2>/dev/null)
    all_source_names="${all_source_names}"$'\n'"${src}"
  done

  distinct_total=$(echo "$all_source_names" | grep -v '^$' | sort -u | wc -l | tr -d ' ')
  log "  Total distinct witness sources (cumulative): $distinct_total"

  if [[ $distinct_total -ge 2 ]]; then
    sources_json=$(printf '%s\n' "${matched_sources[@]}" | python3 -c "
import json, sys
items = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try:
            d = json.loads(line)
            items.append({'source': d.get('source',''), 'url': d.get('url',''), 'fetched_at': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'})
        except: pass
print(json.dumps(items))
" 2>/dev/null)
    promote_item "$f" "fact_candidate" "$sources_json"
    log "  PROMOTED: reinforced_claim → fact_candidate"
    ((pass2_promoted++)) || true
  else
    log "  NOT_PROMOTED: need ≥2 distinct witness sources, have $distinct_total"
  fi
done

log ""
log "Pass 2 source tallies:"
for src in arxiv crossref inspire nist; do
  log "  $src: ${SRC_HITS[$src]} hits / ${SRC_ATTEMPTS[$src]} attempts"
done
log "Pass 2 complete: ${pass2_promoted}/${pass2_total} promoted to fact_candidate"

# ══════════════════════════════════════════════════════════════════════════════
# PROMOTION QUEUE (skip in dry-run and shadow mode)
# ══════════════════════════════════════════════════════════════════════════════
if ! $DRY_RUN && [ -z "$SHADOW_DIR" ]; then
  log ""
  log "── Running run_promotion_queue.sh ────────────────────────"
  if [[ -f "$PROMOTE_SCRIPT" ]]; then
    bash "$PROMOTE_SCRIPT" 2>&1 | tee -a "$LOG"
  else
    log "ERROR: promotion script not found: $PROMOTE_SCRIPT"
  fi
fi

log ""
log "════════════════════════════════════════════════════════"
log "verify_claims.sh v2 complete"
log "  Pass 1: ${pass1_promoted}/${pass1_total} claim → reinforced_claim"
log "  Pass 2: ${pass2_promoted}/${pass2_total} reinforced_claim → fact_candidate"
log "  Dry run: ${DRY_RUN}"
log "  Log: $LOG"
log "════════════════════════════════════════════════════════"
