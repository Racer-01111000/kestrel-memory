#!/usr/bin/env bash
# verify_claims.sh
# Two-pass claim verification via bounded w3m searches.
#
# Pass 1: claim         → reinforced_claim
# Pass 2: reinforced_claim → fact_candidate
# Sources tried per query: arxiv, wikipedia, scholar (+ source_url fallback)
# Corroboration threshold: ≥2 sources each returning ≥MIN_CONTENT_CHARS with ≥MIN_TERM_HITS

set -euo pipefail

STAGED="$HOME/kestrel-memory/knowledge/staged"
RUNTIME="$HOME/kestrel-memory/runtime"
LOG="$RUNTIME/verify_claims.log"
PROMOTE_SCRIPT="$RUNTIME/run_promotion_queue.sh"

W3M_TIMEOUT=25
MIN_TERM_HITS=2
MIN_CORROBORATING=2
MIN_CONTENT_CHARS=500

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── logging ───────────────────────────────────────────────────────────────────
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOG"; }

log "════════════════════════════════════════════════════════"
log "verify_claims.sh started"
log "Staged dir : $STAGED"
log "════════════════════════════════════════════════════════"

# ── key-term extraction ───────────────────────────────────────────────────────
extract_terms() {
  local text="$1"
  python3 -c "
import re, sys
STOP = {
    'that','this','with','from','have','does','will','about','into',
    'than','more','also','some','been','they','their','which','where',
    'when','what','while','would','could','should','these','those',
    'were','been','being','each','both','after','before','other',
    'over','under','only','very','just','then','than','even','well',
    'much','many','most','such','used','uses','using','based','data',
    'high','low','large','small','include','includes','including',
    'provide','provides','provided','show','shows','showed','result',
    'results','paper','study','research','model','models','system',
    'systems','method','methods','approach','approaches','work','works',
}
text = sys.argv[1].lower()
text = re.sub(r'[^a-z0-9 ]', ' ', text)
words = [w for w in text.split() if len(w) >= 4 and w not in STOP]
seen = {}
for w in words:
    seen[w] = seen.get(w, 0) + 1
ordered = sorted(seen.keys(), key=lambda w: -seen[w])
print(' '.join(ordered[:12]))
" "$text"
}

# ── URL-encode ────────────────────────────────────────────────────────────────
urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# ── single w3m fetch + corroboration check ────────────────────────────────────
# Returns 0 (corroborated) or 1 (not).
check_source() {
  local url="$1" terms="$2" out_file="$3" label="$4"
  local tmpfile
  tmpfile=$(mktemp /tmp/verify_claims_XXXXXX.txt)

  if ! timeout "$W3M_TIMEOUT" w3m -dump "$url" > "$tmpfile" 2>/dev/null; then
    log "    [$label] FETCH_TIMEOUT: $url"
    rm -f "$tmpfile"
    return 1
  fi

  local char_count
  char_count=$(wc -c < "$tmpfile" 2>/dev/null || echo 0)
  if [[ $char_count -lt $MIN_CONTENT_CHARS ]]; then
    log "    [$label] REJECTED (too short: ${char_count} chars): $url"
    rm -f "$tmpfile"
    return 1
  fi

  local hits=0
  for term in $terms; do
    grep -qi "$term" "$tmpfile" 2>/dev/null && ((hits++)) || true
  done

  rm -f "$tmpfile"

  if [[ $hits -ge $MIN_TERM_HITS ]]; then
    log "    [$label] CORROBORATED (${hits} term hits, ${char_count} chars): $url"
    echo "$url" >> "$out_file"
    return 0
  else
    log "    [$label] NOT_RELEVANT (${hits} term hits, ${char_count} chars): $url"
    return 1
  fi
}

# ── verify one file ───────────────────────────────────────────────────────────
# Args: file  from_level  to_level  terms  source_url_fallback
# Returns 0 if promoted, 1 if not.
verify_and_promote() {
  local file="$1" from_level="$2" to_level="$3"
  local terms="$4" source_url="$5"
  local sources_file
  sources_file=$(mktemp /tmp/verify_sources_XXXXXX.txt)

  local q
  q=$(urlencode "$terms")

  local arxiv_url="https://arxiv.org/search/?searchtype=all&query=${q}"
  local wiki_url="https://en.wikipedia.org/w/index.php?search=${q}"
  local scholar_url="https://scholar.google.com/scholar?q=${q}"

  local total_corr=0

  log "  Terms: $terms"

  check_source "$arxiv_url"  "$terms" "$sources_file" "arxiv"   && ((total_corr++)) || true
  check_source "$wiki_url"   "$terms" "$sources_file" "wiki"    && ((total_corr++)) || true

  if [[ $total_corr -lt $MIN_CORROBORATING ]]; then
    check_source "$scholar_url" "$terms" "$sources_file" "scholar" && ((total_corr++)) || true
  fi

  # Fallback: fetch source_url directly from the artifact
  if [[ $total_corr -lt $MIN_CORROBORATING && -n "$source_url" ]]; then
    log "  Trying source_url fallback: $source_url"
    check_source "$source_url" "$terms" "$sources_file" "source_url" && ((total_corr++)) || true
  fi

  log "  Corroborating sources: ${total_corr}/${MIN_CORROBORATING} required"

  if [[ $total_corr -ge $MIN_CORROBORATING ]]; then
    local sources_list now
    sources_list=$(cat "$sources_file" | tr '\n' '|' | sed 's/|$//')
    rm -f "$sources_file"
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    FILE_PATH="$file" NEW_LEVEL="$to_level" SOURCES="$sources_list" TS="$now" \
    python3 - << 'PYEOF'
import json, os
path = os.environ["FILE_PATH"]
new_level = os.environ["NEW_LEVEL"]
sources = os.environ["SOURCES"].split("|")
ts = os.environ["TS"]
with open(path) as f:
    d = json.load(f)
d["epistemic_level"] = new_level
d["verification_sources"] = d.get("verification_sources", []) + sources
d["last_verified_at"] = ts
with open(path, "w") as f:
    json.dump(d, f, indent=2)
PYEOF
    log "  PROMOTED: $from_level → $to_level"
    log "  Sources: $sources_list"
    return 0
  else
    rm -f "$sources_file"
    log "  NOT_PROMOTED: insufficient corroboration"
    return 1
  fi
}

# ── extract source_url from a JSON file ──────────────────────────────────────
get_source_url() {
  python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('source_url') or d.get('source') or '')
except:
    print('')
" "$1"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASS 1: claim → reinforced_claim
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "── PASS 1: claim → reinforced_claim ──────────────────────"

pass1_total=0
pass1_promoted=0

for f in "$STAGED"/*.json; do
  [[ -f "$f" ]] || continue

  level=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('epistemic_level',''))
except: print('')
" "$f")
  [[ "$level" == "claim" ]] || continue
  ((pass1_total++)) || true

  title=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('title',''))
except: print('')
" "$f")

  text=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('text','')[:800])
except: print('')
" "$f")

  source_url=$(get_source_url "$f")
  fname=$(basename "$f")
  log ""
  log "FILE: $fname"
  log "  Title: $title"
  log "  Level: claim"

  if [[ -z "$text" ]]; then
    log "  SKIP: empty text field"
    continue
  fi

  all_terms=$(extract_terms "$text")
  title_clean=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | xargs)
  terms="${title_clean} $(echo "$all_terms" | tr ' ' '\n' | head -6 | tr '\n' ' ')"
  terms=$(echo "$terms" | xargs)
  [[ -z "$terms" ]] && terms="$title_clean"

  verify_and_promote "$f" "claim" "reinforced_claim" "$terms" "$source_url" \
    && ((pass1_promoted++)) || true
done

log ""
log "Pass 1 complete: ${pass1_promoted}/${pass1_total} promoted to reinforced_claim"

# ══════════════════════════════════════════════════════════════════════════════
# PASS 2: reinforced_claim → fact_candidate
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "── PASS 2: reinforced_claim → fact_candidate ─────────────"

pass2_total=0
pass2_promoted=0

for f in "$STAGED"/*.json; do
  [[ -f "$f" ]] || continue

  level=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('epistemic_level',''))
except: print('')
" "$f")
  [[ "$level" == "reinforced_claim" ]] || continue
  ((pass2_total++)) || true

  title=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('title',''))
except: print('')
" "$f")

  text=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('text','')[:800])
except: print('')
" "$f")

  source_url=$(get_source_url "$f")
  fname=$(basename "$f")
  log ""
  log "FILE: $fname"
  log "  Title: $title"
  log "  Level: reinforced_claim"

  if [[ -z "$text" ]]; then
    log "  SKIP: empty text field"
    continue
  fi

  all_terms=$(extract_terms "$text")
  title_clean=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | xargs)
  domain=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1])); print(d.get('domain',''))
except: print('')
" "$f" | tr '_' ' ' | sed 's/[^a-z0-9 ]/ /g' | xargs)

  terms="${title_clean} ${domain} $(echo "$all_terms" | tr ' ' '\n' | head -5 | tr '\n' ' ')"
  terms=$(echo "$terms" | xargs)
  [[ -z "$terms" ]] && terms="$title_clean"

  verify_and_promote "$f" "reinforced_claim" "fact_candidate" "$terms" "$source_url" \
    && ((pass2_promoted++)) || true
done

log ""
log "Pass 2 complete: ${pass2_promoted}/${pass2_total} promoted to fact_candidate"

# ══════════════════════════════════════════════════════════════════════════════
# PROMOTION QUEUE
# ══════════════════════════════════════════════════════════════════════════════
log ""
log "── Running run_promotion_queue.sh ────────────────────────"

if [[ -f "$PROMOTE_SCRIPT" ]]; then
  bash "$PROMOTE_SCRIPT" 2>&1 | tee -a "$LOG"
else
  log "ERROR: promotion script not found: $PROMOTE_SCRIPT"
fi

log ""
log "════════════════════════════════════════════════════════"
log "verify_claims.sh complete"
log "  Pass 1: ${pass1_promoted}/${pass1_total} claim → reinforced_claim"
log "  Pass 2: ${pass2_promoted}/${pass2_total} reinforced_claim → fact_candidate"
log "  Log: $LOG"
log "════════════════════════════════════════════════════════"
