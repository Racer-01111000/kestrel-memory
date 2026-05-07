#!/usr/bin/env bash
set -euo pipefail
URL="${1:?usage: stage_url.sh <url>}"
URL="${URL/arxiv.org\/html\//arxiv.org\/abs\/}"
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUTFILE="$HOME/kestrel-memory/knowledge/staged/tg_url_${TS}.json"
python3 -c "
import json, sys
print(json.dumps({'url': sys.argv[1], 'staged_at': sys.argv[2], 'source': 'sidebar_submit'}, indent=2))
" "$URL" "$TS" > "$OUTFILE"
echo "staged: $OUTFILE"
