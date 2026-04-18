#!/usr/bin/env bash
# verify_claims.sh
# Two-pass claim verification via bounded w3m searches.
#
# Pass 1: claim         → reinforced_claim  (2 DDG searches, content-derived terms)
# Pass 2: reinforced_claim → fact_candidate (2 DDG searches, title-derived terms)
# Then runs run_promotion_queue.sh.
#
# Corroboration threshold: ≥2 sources each returning ≥2 key-term hits.

set -euo pipefail

STAGED="$HOME/kestrel-memory/knowledge/staged"
RUNTIME="$HOME/kestrel-memory/runtime"
LOG="$RUNTIME/verify_claims.log"
PROMOTE_SCRIPT="$RUNTIME/run_promotion_queue.sh"

W3M_TIMEOUT=25
MIN_TERM_HITS=2
MIN_CORROBORATING=2
MIN_CONTENT_CHARS=150

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── logging ───────────────────────────────────────────────────────────────────
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOG"; }
log_raw() { echo "$*" | tee -a "$LOG"; }

log "════════════════════════════════════════════════════════"
log "verify_claims.sh started"
log "Staged dir : $STAGED"
log "════════════════════════════════════════════════════════"

# ── key-term extraction ───────────────────────────────────────────────────────
# Returns space-separated terms, deduped, ≥4 chars, no stopwords.
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
# sort by frequency desc, take top 12
ordered = sorted(seen.keys(), key=lambda w: -seen[w])
print(' '.join(ordered[:12]))
" "$text"
}

# ── URL-encode ────────────────────────────────────────────────────────────────
urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# ── single w3m fetch + corroboration check ────────────────────────────────────
# Returns 0 (corroborated) or 1 (not). Appends source info to $SOURCES_OUT.
# Args: url key_terms_space_separated sources_out_file
check_source() {
  local url="$1" terms="$2" out_file="$3"
  local tmpfile
  tmpfile=$(mktemp /tmp/verify_claims_XXXXXX.txt)

  if ! timeout "$W3M_TIMEOUT" w3m -dump "$url" > "$tmpfile" 2>/dev/null; then
    log "    FETCH_TIMEOUT: $url"
    rm -f "$tmpfile"
    return 1
  fi

  local char_count
  char_count=$(wc -c < "$tmpfile" 2>/dev/null || echo 0)
  if [[ $char_count -lt $MIN_CONTENT_CHARS ]]; then
    log "    REJECTED (too short: ${char_count} chars): $url"
    rm -f "$tmpfile"
    return 1
  fi

  local hits=0
  for term in $terms; do
    grep -qi "$term" "$tmpfile" 2>/dev/null && ((hits++)) || true
  done

  rm -f "$tmpfile"

  if [[ $hits -ge $MIN_TERM_HITS ]]; then
    log "    CORROBORATED (${hits} term hits, ${char_count} chars): $url"
    echo "$url" >> "$out_file"
    return 0
  else
    log "    NOT_RELEVANT (${hits} term hits): $url"
    return 1
  fi
}

# ── verify one file (both terms sets) ────────────────────────────────────────
# Args: file  from_level  to_level  terms_set_1  terms_set_2
# Returns 0 if promoted, 1 if not.
verify_and_promote() {
  local file="$1" from_level="$2" to_level="$3"
  local terms1="$4" terms2="$5"
  local sources_file
  sources_file=$(mktemp /tmp/verify_sources_XXXXXX.txt)

  local q1 q2 url1 url2
  q1=$(urlencode "$terms1")
  q2=$(urlencode "$terms2")
  url1="https://html.duckduckgo.com/html/?q=${q1}"
  url2="https://html.duckduckgo.com/html/?q=${q2}"

  log "  Search 1: $terms1"
  local corr1=0
  check_source "$url1" "$terms1" "$sources_file" && corr1=1 || true

  log "  Search 2: $terms2"
  local corr2=0
  check_source "$url2" "$terms2" "$sources_file" && corr2=1 || true

  local total_corr=$((corr1 + corr2))
  log "  Corroborating sources: ${total_corr}/${MIN_CORROBORATING} required"

  if [[ $total_corr -ge $MIN_CORROBORATING ]]; then
    local sources_list
    sources_list=$(cat "$sources_file" | tr '\n' '|' | sed 's/|$//')
    rm -f "$sources_file"

    # Update JSON in place
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    FILE_PATH="$file" NEW_LEVEL="$to_level" SOURCES="$sources_list" TS="$now" \
    python3 - << 'PYEOF'
import json, os, sys
path = os.environ["FILE_PATH"]
new_level = os.environ["NEW_LEVEL"]
sources = os.environ["SOURCES"].split("|")
ts = os.environ["TS"]

with open(path) as f:
    d = json.load(f)

d["epistemic_level"] = new_level
prev = d.get("verification_sources", [])
d["verification_sources"] = prev + sources
d["last_verified_at"] = ts

with open(path, "w") as f:
    json.dump(d, f, indent=2)
PYEOF
    log "  PROMOTED: $from_level → $to_level"
    log "  Sources logged: $sources_list"
    return 0
  else
    rm -f "$sources_file"
    log "  NOT_PROMOTED: insufficient corroboration"
    return 1
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PASS 1: claim → reinforced_claim
# Search strategy: content-key-terms query + title query
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
    d=json.load(open(sys.argv[1]))
    print(d.get('epistemic_level',''))
except: print('')
" "$f")

  [[ "$level" == "claim" ]] || continue
  ((pass1_total++)) || true

  title=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('title',''))
except: print('')
" "$f")

  text=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('text','')[:800])
except: print('')
" "$f")

  fname=$(basename "$f")
  log ""
  log "FILE: $fname"
  log "  Title: $title"
  log "  Level: claim"

  if [[ -z "$text" ]]; then
    log "  SKIP: empty text field"
    continue
  fi

  # Terms set 1: top key terms from text content
  all_terms=$(extract_terms "$text")
  terms1=$(echo "$all_terms" | tr ' ' '\n' | head -6 | tr '\n' ' ' | xargs)

  # Terms set 2: title words + next batch of content terms
  title_clean=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | xargs)
  terms2_body=$(echo "$all_terms" | tr ' ' '\n' | tail -n +5 | head -4 | tr '\n' ' ' | xargs)
  terms2="${title_clean} ${terms2_body}"
  terms2=$(echo "$terms2" | xargs)  # trim

  # Fall back if terms are empty
  [[ -z "$terms1" ]] && terms1="$title_clean"
  [[ -z "$terms2" ]] && terms2="$title_clean"

  verify_and_promote "$f" "claim" "reinforced_claim" "$terms1" "$terms2" \
    && ((pass1_promoted++)) || true
done

log ""
log "Pass 1 complete: ${pass1_promoted}/${pass1_total} promoted to reinforced_claim"

# ══════════════════════════════════════════════════════════════════════════════
# PASS 2: reinforced_claim → fact_candidate
# Search strategy: title-first query + domain + alternate content terms
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
    d=json.load(open(sys.argv[1]))
    print(d.get('epistemic_level',''))
except: print('')
" "$f")

  [[ "$level" == "reinforced_claim" ]] || continue
  ((pass2_total++)) || true

  title=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('title',''))
except: print('')
" "$f")

  text=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('text','')[:800])
except: print('')
" "$f")

  domain=$(python3 -c "
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get('domain',''))
except: print('')
" "$f")

  fname=$(basename "$f")
  log ""
  log "FILE: $fname"
  log "  Title: $title"
  log "  Level: reinforced_claim"

  if [[ -z "$text" ]]; then
    log "  SKIP: empty text field"
    continue
  fi

  title_clean=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]/ /g' | xargs)
  all_terms=$(extract_terms "$text")

  # Terms set 1: title-first approach (different angle from pass 1)
  terms1="${title_clean}"
  [[ -z "$terms1" ]] && terms1=$(echo "$all_terms" | tr ' ' '\n' | head -4 | tr '\n' ' ' | xargs)

  # Terms set 2: domain + alternate content terms (skip first 4 already used in pass 1)
  domain_clean=$(echo "$domain" | tr '_' ' ' | sed 's/[^a-z0-9 ]/ /g' | xargs)
  terms2_body=$(echo "$all_terms" | tr ' ' '\n' | tail -n +7 | head -5 | tr '\n' ' ' | xargs)
  terms2="${domain_clean} ${terms2_body}"
  terms2=$(echo "$terms2" | xargs)
  [[ -z "$terms2" ]] && terms2="$title_clean"

  verify_and_promote "$f" "reinforced_claim" "fact_candidate" "$terms1" "$terms2" \
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

# ── summary ───────────────────────────────────────────────────────────────────
log ""
log "════════════════════════════════════════════════════════"
log "verify_claims.sh complete"
log "  Pass 1: ${pass1_promoted}/${pass1_total} claim → reinforced_claim"
log "  Pass 2: ${pass2_promoted}/${pass2_total} reinforced_claim → fact_candidate"
log "  Log: $LOG"
log "════════════════════════════════════════════════════════"
