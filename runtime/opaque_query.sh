#!/usr/bin/env bash
# opaque_query.sh — NODE-FIRST UNKNOWNS policy (v0.1)
# Usage: opaque_query.sh "<question>"
# Output (last line): SUFFICIENT_FOR_RESPONSE | INSUFFICIENT | CONFLICTED
#
# Invariant: acquisition ≠ evidence ≠ sufficiency ≠ promotion
# Retrieval is candidate evidence only. Sufficiency is tested separately.
# Telegram escalation fires only when proof remains inadequate.

set -euo pipefail

QUESTION="${1:-}"
if [[ -z "$QUESTION" ]]; then
  echo "Usage: $0 '<question>'" >&2
  exit 1
fi

STAGING_BASE="$HOME/kestrel-memory/staging/opaque"
RUNTIME="$HOME/kestrel-memory/runtime"
TIMESTAMP=$(date +%Y%m%dT%H%M%SZ)
RUN_DIR="$STAGING_BASE/$TIMESTAMP"
LOG="$RUNTIME/opaque_query_$TIMESTAMP.log"

mkdir -p "$RUN_DIR" "$RUNTIME"

# ── telegram config ──────────────────────────────────────────────────────────
TELEGRAM_TOKEN="8683141167:AAETRtx5zflyoirU-yJjzSnTb3QPDMcNvqc"
TELEGRAM_CHAT_ID="7823716967"

# ── bounds ───────────────────────────────────────────────────────────────────
MAX_SOURCES=4
MIN_USABLE=2
MIN_CONTENT_CHARS=300
W3M_TIMEOUT=30

log() { echo "$*" | tee -a "$LOG"; }

# ── build candidate source list ───────────────────────────────────────────────
DDG_Q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUESTION")
WIKI_Q=$(python3 -c "
import urllib.parse, sys, re
q = sys.argv[1]
# take first 5 words for wiki title attempt
title = '_'.join(re.sub(r'[^a-z0-9 ]', '', q.lower()).split()[:5])
print(urllib.parse.quote(title))
" "$QUESTION")

SOURCES=(
  "https://html.duckduckgo.com/html/?q=${DDG_Q}"
  "https://en.wikipedia.org/wiki/${WIKI_Q}"
  "https://www.google.com/search?q=${DDG_Q}&num=5"
  "https://search.yahoo.com/search?p=${DDG_Q}"
)

# ── word set for relevance matching ──────────────────────────────────────────
# Extract non-trivial words (>=4 chars) from the question
CLEAN_WORDS=$(python3 -c "
import re, sys
q = sys.argv[1].lower()
q = re.sub(r'[^a-z0-9 ]', ' ', q)
words = [w for w in q.split() if len(w) >= 4 and w not in {
    'what','when','where','which','that','this','with','from','have',
    'does','will','about','into','than','more','also','some','been'
}]
print(' '.join(dict.fromkeys(words)))  # deduplicated, order preserved
" "$QUESTION")

log "=== OPAQUE QUERY RUN ==="
log "Question : $QUESTION"
log "Timestamp: $TIMESTAMP"
log "Key terms: $CLEAN_WORDS"
log "Run dir  : $RUN_DIR"
log ""

# ── bounded w3m retrieval ─────────────────────────────────────────────────────
usable=0
matched=0
declare -a artifact_files=()
declare -a domains=()
declare -a relevance_scores=()

for i in "${!SOURCES[@]}"; do
  [[ $i -ge $MAX_SOURCES ]] && break
  url="${SOURCES[$i]}"
  artifact="$RUN_DIR/artifact_$(printf '%02d' $((i+1))).txt"
  meta="$RUN_DIR/artifact_$(printf '%02d' $((i+1))).json"
  domain=$(python3 -c "import urllib.parse,sys; u=urllib.parse.urlparse(sys.argv[1]); print(u.netloc)" "$url")

  log "Fetch $((i+1))/$MAX_SOURCES: $url"

  if timeout "$W3M_TIMEOUT" w3m -dump "$url" > "$artifact" 2>/dev/null && [[ -s "$artifact" ]]; then
    char_count=$(wc -c < "$artifact")
    if [[ $char_count -lt $MIN_CONTENT_CHARS ]]; then
      log "  -> REJECTED (too short: $char_count chars)"
      rm -f "$artifact"
      continue
    fi

    # relevance: count how many key terms appear in the artifact
    term_hits=0
    for word in $CLEAN_WORDS; do
      grep -qi "$word" "$artifact" 2>/dev/null && ((term_hits++)) || true
    done

    # need >=2 key terms to qualify as relevant
    if [[ $term_hits -lt 2 ]]; then
      log "  -> REJECTED (only $term_hits term hits)"
      rm -f "$artifact"
      continue
    fi

    log "  -> USABLE ($char_count chars, $term_hits term hits, domain=$domain)"
    ((usable++)) || true
    artifact_files+=("$artifact")
    domains+=("$domain")
    relevance_scores+=("$term_hits")

    python3 -c "
import json, sys
data = {
    'source_url': sys.argv[1],
    'domain': sys.argv[2],
    'char_count': int(sys.argv[3]),
    'term_hits': int(sys.argv[4]),
    'status': 'fetched',
    'timestamp': sys.argv[5],
    'question': sys.argv[6],
}
print(json.dumps(data, indent=2))
" "$url" "$domain" "$char_count" "$term_hits" "$TIMESTAMP" "$QUESTION" > "$meta"

    ((matched++)) || true
  else
    log "  -> FETCH_ERROR"
    rm -f "$artifact"
  fi
done

log ""
log "Usable / attempted : $usable / $MAX_SOURCES"
log "Relevant matched   : $matched"

# ── distinct domain count ─────────────────────────────────────────────────────
distinct_domains=0
if [[ ${#domains[@]} -gt 0 ]]; then
  distinct_domains=$(printf '%s\n' "${domains[@]}" | sort -u | wc -l)
fi
log "Distinct domains   : $distinct_domains"

# ── conflict detection ────────────────────────────────────────────────────────
# Heuristic: check if term-hit scores vary by more than 3x across matched
# sources — large disparity signals inconsistent coverage / possible conflict.
CONFLICTED_SIGNAL=0
if [[ ${#relevance_scores[@]} -ge 2 ]]; then
  max_score=0
  min_score=9999
  for s in "${relevance_scores[@]}"; do
    [[ $s -gt $max_score ]] && max_score=$s
    [[ $s -lt $min_score ]] && min_score=$s
  done
  # flag conflict if best source is >3x as relevant as worst
  if [[ $min_score -gt 0 && $max_score -ge $((min_score * 3)) ]]; then
    CONFLICTED_SIGNAL=1
    log "Conflict signal    : YES (scores $min_score–$max_score, ratio $(( max_score / min_score ))x)"
  fi
fi

# ── sufficiency decision ──────────────────────────────────────────────────────
OUTCOME=""
REASON=""

if [[ $CONFLICTED_SIGNAL -eq 1 ]]; then
  OUTCOME="CONFLICTED"
  REASON="sources show inconsistent relevance coverage — requires operator review before answer"
elif [[ $usable -ge $MIN_USABLE && $matched -ge $MIN_USABLE && $distinct_domains -ge $MIN_USABLE ]]; then
  OUTCOME="SUFFICIENT_FOR_RESPONSE"
  REASON="$matched relevant artifacts from $distinct_domains distinct domains"
else
  OUTCOME="INSUFFICIENT"
  if [[ $usable -lt $MIN_USABLE ]]; then
    REASON="only $usable usable artifact(s) retrieved (need $MIN_USABLE)"
  elif [[ $matched -lt $MIN_USABLE ]]; then
    REASON="only $matched artifact(s) matched question terms (need $MIN_USABLE)"
  else
    REASON="only $distinct_domains distinct domain(s) (need $MIN_USABLE)"
  fi
fi

log ""
log "OUTCOME: $OUTCOME"
log "REASON : $REASON"
log ""

# ── write run summary ─────────────────────────────────────────────────────────
python3 -c "
import json, sys
data = {
    'question': sys.argv[1],
    'outcome': sys.argv[2],
    'reason': sys.argv[3],
    'usable_sources': int(sys.argv[4]),
    'matched_sources': int(sys.argv[5]),
    'distinct_domains': int(sys.argv[6]),
    'timestamp': sys.argv[7],
    'run_dir': sys.argv[8],
}
print(json.dumps(data, indent=2))
" "$QUESTION" "$OUTCOME" "$REASON" "$usable" "$matched" "$distinct_domains" \
  "$TIMESTAMP" "$RUN_DIR" > "$RUN_DIR/summary.json"

# ── telegram escalation ───────────────────────────────────────────────────────
# Policy §6–8: escalate only after bounded retrieval has been attempted and
# the remaining gap is real and material. Do not escalate for every uncertainty.
if [[ "$OUTCOME" == "INSUFFICIENT" || "$OUTCOME" == "CONFLICTED" ]]; then
  if [[ "$OUTCOME" == "INSUFFICIENT" ]]; then
    STATUS_LINE="INSUFFICIENT — proof gap after bounded retrieval"
  else
    STATUS_LINE="CONFLICTED — sources show inconsistent relevance, cannot ground answer"
  fi

  MSG="[KESTREL OPAQUE QUERY ESCALATION]

Question: $QUESTION

Retrieval summary:
  Sources attempted : $MAX_SOURCES (w3m bounded fetch)
  Usable artifacts  : $usable
  Relevant matched  : $matched
  Distinct domains  : $distinct_domains

Outcome: $STATUS_LINE
Failure reason: $REASON

Artifacts staged: $RUN_DIR
Run ID: $TIMESTAMP

Required from operator: judgment, approval, or additional grounding for this question."

  log "Sending Telegram escalation..."
  ENCODED_MSG=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$MSG")
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MSG}" \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage") || true
  log "Telegram HTTP status: $HTTP_STATUS"
fi

# ── final output (exactly one token on last line) ─────────────────────────────
echo "$OUTCOME"
