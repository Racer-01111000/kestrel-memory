#!/usr/bin/env bash
# lib/sources.sh — witness and discovery functions for verify_claims.sh
#
# SOURCE TIERS:
#   Discovery (non-voting): OpenAlex, Semantic Scholar
#     — used to find candidate papers; their confirmation does NOT count as a witness.
#   Witness (voting): arXiv API, Crossref, INSPIRE-HEP, NIST/CSRC
#     — independent editorial/submission paths; each successful hit increments corroboration.
#
# Why discovery sources don't vote:
#   OpenAlex and S2 are aggregators that index arXiv, Crossref, etc.
#   A hit in OpenAlex that traces back to an arXiv paper is the SAME witness
#   as the arXiv hit — counting both would be counting one source twice.

CURL_TIMEOUT=15
ARXIV_SLEEP=3   # arXiv API: 1 req/3 sec max
SOURCE_SLEEP=1  # other sources

# ── helpers ──────────────────────────────────────────────────────────────────

_urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# Strips HTML/XML tags and collapses whitespace.
_strip_tags() {
  python3 -c "
import re, sys
text = sys.stdin.read()
text = re.sub(r'<[^>]+>', ' ', text)
text = re.sub(r'\s+', ' ', text).strip()
print(text)
"
}

# ── corroboration matching ────────────────────────────────────────────────────
# Returns 0 if text corroborates claim (>=500 chars AND >=3 content words match).
match_corroboration() {
  local claim="$1" text="$2"
  [ ${#text} -ge 500 ] || return 1
  local hits=0
  local word
  local text_lower
  text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')
  for word in $(echo "$claim" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' '); do
    [ ${#word} -lt 4 ] && continue
    echo "$text_lower" | grep -q "$word" && hits=$((hits + 1))
    [ $hits -ge 3 ] && return 0
  done
  return 1
}

# ── DISCOVERY: OpenAlex ───────────────────────────────────────────────────────
# Stdout: newline-separated DOIs / arXiv URLs
query_openalex() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local resp
  resp=$(curl -sS --max-time "$CURL_TIMEOUT" \
    "https://api.openalex.org/works?search=${q}&per-page=5&mailto=bahnmirick@gmail.com" \
    2>/dev/null) || return 1
  echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for w in d.get('results', []):
        doi = w.get('doi') or ''
        ids = w.get('ids', {})
        arxiv = ids.get('arxiv') or ''
        if doi: print(doi)
        if arxiv: print(arxiv)
except:
    pass
" 2>/dev/null
  sleep "$SOURCE_SLEEP"
}

# ── DISCOVERY: Semantic Scholar ───────────────────────────────────────────────
# Stdout: newline-separated DOIs / arXiv IDs
query_semantic_scholar() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local resp
  resp=$(curl -sS --max-time "$CURL_TIMEOUT" \
    "https://api.semanticscholar.org/graph/v1/paper/search?query=${q}&limit=5&fields=title,externalIds" \
    2>/dev/null) || return 1

  if echo "$resp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
code=str(d.get('code',''))
msg=str(d.get('message',''))
if '429' in code or 'Too Many' in msg: sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    log "    [s2] RATE_LIMITED — skipping for this run"
    return 1
  fi

  echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for p in d.get('data', []):
        ids = p.get('externalIds') or {}
        doi = ids.get('DOI') or ''
        arxiv = ids.get('ArXiv') or ''
        if doi: print('https://doi.org/' + doi)
        if arxiv: print('https://arxiv.org/abs/' + arxiv)
except:
    pass
" 2>/dev/null
  sleep "$SOURCE_SLEEP"
}

# ── WITNESS: arXiv API ────────────────────────────────────────────────────────
# Stdout: JSON array of {source, url, text}
witness_arxiv() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local resp
  resp=$(curl -sS --max-time "$CURL_TIMEOUT" \
    "https://export.arxiv.org/api/query?search_query=all:${q}&max_results=5" \
    2>/dev/null) || { echo "[]"; return 1; }

  # Handle 429 or empty response
  if [ -z "$resp" ] || echo "$resp" | grep -q "Too Many Requests\|rate.limit"; then
    log "    [arxiv] RATE_LIMITED or empty — skipping"
    echo "[]"; return 1
  fi

  python3 -c "
import sys, json
import xml.etree.ElementTree as ET
ns = {'atom': 'http://www.w3.org/2005/Atom'}
try:
    root = ET.fromstring(sys.stdin.read())
    results = []
    for entry in root.findall('atom:entry', ns):
        title = (entry.findtext('atom:title', '', ns) or '').strip()
        summary = (entry.findtext('atom:summary', '', ns) or '').strip()
        url = (entry.findtext('atom:id', '', ns) or '').strip()
        text = title + ' ' + summary
        results.append({'source': 'arxiv', 'url': url, 'text': text})
    print(json.dumps(results))
except Exception as e:
    print('[]')
" <<< "$resp" 2>/dev/null
  sleep "$ARXIV_SLEEP"
}

# ── WITNESS: Crossref ─────────────────────────────────────────────────────────
# Stdout: JSON array of {source, url, text}
witness_crossref() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local resp
  resp=$(curl -sS --max-time "$CURL_TIMEOUT" \
    -H "User-Agent: kestrel/2.0 (mailto:bahnmirick@gmail.com)" \
    "https://api.crossref.org/works?query=${q}&rows=5" \
    2>/dev/null) || { echo "[]"; return 1; }

  python3 -c "
import json, sys, re
try:
    d = json.load(sys.stdin)
    results = []
    for item in d.get('message', {}).get('items', []):
        title = ' '.join(item.get('title', []))
        abstract = item.get('abstract', '')
        abstract = re.sub(r'<[^>]+>', ' ', abstract)
        url = item.get('URL') or ('https://doi.org/' + item.get('DOI', ''))
        text = (title + ' ' + abstract).strip()
        results.append({'source': 'crossref', 'url': url, 'text': text})
    print(json.dumps(results))
except:
    print('[]')
" <<< "$resp" 2>/dev/null
  sleep "$SOURCE_SLEEP"
}

# ── WITNESS: INSPIRE-HEP ──────────────────────────────────────────────────────
# Stdout: JSON array of {source, url, text}
# Note: inspirehep.net may be unreachable from some networks; fails soft.
witness_inspire() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local resp
  resp=$(curl -sS --max-time "$CURL_TIMEOUT" \
    "https://inspirehep.net/api/literature?q=${q}&size=5&fields=titles,abstracts,arxiv_eprints,dois" \
    2>/dev/null) || { echo "[]"; return 1; }
  [ -z "$resp" ] && { echo "[]"; return 1; }

  python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    results = []
    for hit in d.get('hits', {}).get('hits', []):
        meta = hit.get('metadata', {})
        titles = meta.get('titles', [{}])
        title = titles[0].get('title', '') if titles else ''
        abstracts = meta.get('abstracts', [{}])
        abstract = abstracts[0].get('value', '') if abstracts else ''
        arxiv_ids = meta.get('arxiv_eprints', [])
        arxiv_id = arxiv_ids[0].get('value', '') if arxiv_ids else ''
        url = ('https://arxiv.org/abs/' + arxiv_id) if arxiv_id else 'https://inspirehep.net'
        text = (title + ' ' + abstract).strip()
        results.append({'source': 'inspire', 'url': url, 'text': text})
    print(json.dumps(results))
except:
    print('[]')
" <<< "$resp" 2>/dev/null
  sleep "$SOURCE_SLEEP"
}

# ── WITNESS: NIST/CSRC (w3m) ─────────────────────────────────────────────────
# Stdout: JSON array of {source, url, text}
witness_nist() {
  local query="$1"
  local q
  q=$(_urlencode "$query")
  local url="https://csrc.nist.gov/publications/search?keywords-lg=${q}"
  local content
  content=$(timeout 20 w3m -dump "$url" 2>/dev/null) || { echo "[]"; return 1; }
  local char_count=${#content}

  python3 -c "
import json, sys
content = sys.argv[1]
if len(content) < 100:
    print('[]')
else:
    print(json.dumps([{'source': 'nist', 'url': sys.argv[2], 'text': content}]))
" "$content" "$url" 2>/dev/null
  sleep "$SOURCE_SLEEP"
}
