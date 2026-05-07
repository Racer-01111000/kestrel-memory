#!/bin/bash
TOKEN="8683141167:AAGPV9pZs3ipNW539U-emNvRztAXk-c1Rjs"
CHAT_ID="7823716967"
OFFSET_FILE="/tmp/tg_bot_offset"
STAGED_DIR="/home/rick/kestrel-memory/knowledge/staged"
RUNTIME_DIR="/home/rick/kestrel-memory/runtime"

send() {
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    --data-urlencode "text=$1" > /dev/null
}

help_text() {
  send "Kestrel commands:
update / status — sufficiency summary + promotion gate count
confirm — last verify_claims.log entries
staged — list staged items and epistemic levels
promote — run promotion queue
verify — run verify_claims.sh now
help — this list
<url> — fetch and stage as new entry
<text >100 chars> — stage as claim"
}

handle_update() {
  local text="$1"
  local lower
  lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

  if echo "$lower" | grep -qi 'update\|status'; then
    local review
    review=$(ls -t "${RUNTIME_DIR}"/sufficiency_review_*.txt 2>/dev/null | head -1)
    local summary
    summary=$(grep -E "^(STATUS:|  PASS:|  WARN:|  FAIL:|  Total:)" "$review" 2>/dev/null | tr '\n' ' ')
    local gate_count
    gate_count=$(python3 -c "
import json, os
gf = os.path.expanduser('~/.kestrel-node/runtime/state/promotion_gate.json')
try:
    d = json.load(open(gf))
    items = d if isinstance(d, list) else d.get('items', d.get('queue', []))
    print(len(items))
except:
    print('unknown')
" 2>/dev/null)
    send "Sufficiency: ${summary} | Promotion gate: ${gate_count} item(s)"

  elif echo "$lower" | grep -qi 'confirm'; then
    local last
    last=$(tail -20 "${RUNTIME_DIR}/verify_claims.log" 2>/dev/null | grep -v '^$' | tail -5)
    send "Last verify_claims.log entries:
${last}"

  elif echo "$lower" | grep -qi 'staged'; then
    local items
    items=$(python3 -c "
import json, os, glob
lines = []
for f in sorted(glob.glob('${STAGED_DIR}/*.json')):
    try:
        d = json.load(open(f))
        title = d.get('title') or d.get('id') or os.path.basename(f)
        level = d.get('epistemic_level') or d.get('epistemic_status') or '?'
        lines.append(title + ' [' + level + ']')
    except:
        pass
print('\n'.join(lines) if lines else 'No staged JSON items.')
" 2>/dev/null)
    send "Staged items:
${items}"

  elif echo "$lower" | grep -qi 'promote'; then
    local result
    result=$(bash "${RUNTIME_DIR}/run_promotion_queue.sh" 2>&1 | tail -20)
    send "Promotion result:
${result}"

  elif echo "$lower" | grep -qi 'verify'; then
    local result
    result=$(bash "${RUNTIME_DIR}/verify_claims.sh" 2>&1 | tail -20)
    send "verify_claims result:
${result}"

  elif echo "$lower" | grep -qi 'help'; then
    help_text

  elif echo "$text" | grep -qi '^http'; then
    local slug ts content
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    slug="tg_url_${ts}"
    content=$(curl -sL --max-time 15 "$text" 2>/dev/null | python3 -c "
import sys, re
html = sys.stdin.read()
text = re.sub(r'<[^>]+>', ' ', html)
text = re.sub(r'\s+', ' ', text).strip()
print(text[:3000])
" 2>/dev/null)
    if [ -z "$content" ]; then
      send "Failed to fetch URL: $text"
      return
    fi
    python3 -c "
import json, sys
d = {
  'id': '${slug}',
  'title': sys.argv[1],
  'source': sys.argv[1],
  'epistemic_level': 'claim',
  'review_status': 'pending',
  'content': sys.argv[2]
}
with open('${STAGED_DIR}/${slug}.json', 'w') as f:
    json.dump(d, f, indent=2)
" "$text" "$content" 2>/dev/null
    send "Staged URL as ${slug}.json [claim]"

  elif [ ${#text} -gt 100 ]; then
    local ts slug
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    slug="tg_ingest_${ts}"
    python3 -c "
import json, sys
d = {
  'id': '${slug}',
  'title': sys.argv[1][:60],
  'source': 'telegram',
  'epistemic_level': 'claim',
  'review_status': 'pending',
  'content': sys.argv[1]
}
with open('${STAGED_DIR}/${slug}.json', 'w') as f:
    json.dump(d, f, indent=2)
" "$text" 2>/dev/null
    send "Staged as ${slug}.json [claim]"

  else
    help_text
  fi
}

OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "0")

while true; do
  RESPONSE=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for u in d.get('result', []):
    uid = u['update_id']
    msg = u.get('message', {}).get('text', '')
    print(str(uid) + '\t' + msg)
" 2>/dev/null | while IFS=$'\t' read -r uid msg; do
    [ -z "$uid" ] && continue
    handle_update "$msg"
    echo $((uid + 1)) > "$OFFSET_FILE"
  done
  OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "$OFFSET")
done
