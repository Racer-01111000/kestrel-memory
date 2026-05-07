#!/usr/bin/env bash
# run_promotion_queue.sh
# Reads ~/kestrel-memory/knowledge/staged/ for items with
# epistemic_level = 'fact_candidate', queues them into promotion_gate.json,
# then evaluates each against the 3-gate doctrine and auto-promotes
# items that pass all three gates.
#
# 3-Gate Doctrine (LOCKED):
#   Gate 1: w3m URL validated (truth_gate_reports/ shows status=validated)
#   Gate 2: Academic API #1 — OpenAlex, INSPIRE-HEP, or Semantic Scholar
#   Gate 3: Academic API #2 — a DIFFERENT source from Gate 2
#   All 3 must pass. Same API twice does NOT satisfy Gates 2+3.
#   Auto-promotes to knowledge/canonical/ when all gates pass.

set -euo pipefail

STAGED="$HOME/kestrel-memory/knowledge/staged"
GATE="$HOME/.kestrel-node/runtime/state/promotion_gate.json"
CANONICAL="$HOME/kestrel-memory/knowledge/canonical"
REPORTS="$HOME/NODE/metadata/truth_gate_reports"

if [ ! -f "$GATE" ]; then
  echo "ERROR: promotion_gate.json not found at $GATE" >&2
  exit 1
fi

STAGED="$STAGED" GATE="$GATE" CANONICAL="$CANONICAL" REPORTS="$REPORTS" python3 - << 'INNERPY'
import json, os, sys, re, urllib.request
from datetime import datetime, timezone
from pathlib import Path

staged_dir    = Path(os.environ["STAGED"])
gate_path     = Path(os.environ["GATE"])
canonical_dir = Path(os.environ["CANONICAL"])
reports_dir   = Path(os.environ["REPORTS"])

with open(gate_path) as f:
    gate = json.load(f)

existing_ids = {item.get("id") for item in gate.get("eligible_items", [])}
queued  = []
skipped = []
now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ── Phase 1: Queue new fact_candidates ────────────────────────────────────────

for fname in sorted(os.listdir(staged_dir)):
    path = staged_dir / fname

    if fname.endswith(".json"):
        try:
            d = json.load(open(path))
        except Exception:
            continue
        if d.get("epistemic_level") != "fact_candidate":
            continue
        item_id = d.get("id", fname.replace(".json", ""))
        if item_id in existing_ids:
            skipped.append(item_id)
            continue
        entry = {
            "id":              item_id,
            "source_file":     "knowledge/staged/" + fname,
            "title":           d.get("title", item_id),
            "epistemic_level": "fact_candidate",
            "classification":  d.get("classification", "staged"),
            "confidence":      d.get("confidence", "unknown"),
            "domain":          d.get("domain", ""),
            "queued_at":       now_iso,
            "review_status":   "pending_promotion",
        }
        gate["eligible_items"].append(entry)
        existing_ids.add(item_id)
        queued.append(entry)

    elif fname.endswith(".md"):
        try:
            content = open(path).read()
        except Exception:
            continue
        el_val = None
        for line in content.splitlines():
            if re.match(r"^-\s+EPISTEMIC_LEVEL:", line, re.IGNORECASE):
                el_val = line.split(":", 1)[1].strip().strip("`").strip()
                break
        if el_val != "fact_candidate":
            continue

        def get_field(label, text):
            for line in text.splitlines():
                m = re.match(r"^-\s+" + label + r":\s*[`]?(.+?)[`]?\s*$", line, re.IGNORECASE)
                if m:
                    return m.group(1).strip()
            return ""

        item_id = get_field("DOC_ID", content) or get_field("ID", content) or fname.replace(".md", "")
        if item_id in existing_ids:
            skipped.append(item_id)
            continue
        entry = {
            "id":              item_id,
            "source_file":     "knowledge/staged/" + fname,
            "title":           get_field("TITLE", content) or get_field("SOURCE_TITLE", content) or item_id,
            "epistemic_level": "fact_candidate",
            "classification":  get_field("CLASSIFICATION", content) or "staged",
            "confidence":      get_field("CONFIDENCE", content) or "unknown",
            "domain":          get_field("DOMAIN", content) or "",
            "queued_at":       now_iso,
            "review_status":   "pending_promotion",
        }
        gate["eligible_items"].append(entry)
        existing_ids.add(item_id)
        queued.append(entry)

print(f"\n=== Promotion Queue Run: {now_iso} ===")
print(f"Staged dir : {staged_dir}")
print(f"Gate file  : {gate_path}")
print(f"Queued     : {len(queued)}")
print(f"Skipped (already queued): {len(skipped)}")
print(f"Total eligible_items now : {len(gate['eligible_items'])}")

# ── Phase 2: 3-Gate Evaluation ────────────────────────────────────────────────

LOOKUP_TIMEOUT = 10
OPENALEX_UA = "kestrel-node/1.0 (mailto:bahnmirick@gmail.com)"

def extract_arxiv_id(item, source_data):
    """Extract arxiv_id from item title or source file data."""
    for src in [item.get("title", ""), source_data.get("title", ""), source_data.get("text", "")[:500]]:
        m = re.search(r'(?:arXiv:|arxiv\.org/abs/)(\d{4}\.\d{4,5})', src, re.IGNORECASE)
        if m:
            return m.group(1)
        m = re.search(r'\[(\d{4}\.\d{4,5})\]', src)
        if m:
            return m.group(1)
    for url in source_data.get("verification_sources", []):
        if "arxiv.org/abs/" in url:
            aid = url.split("arxiv.org/abs/")[-1].split("v")[0].strip()
            if re.match(r'^\d{4}\.\d{4,5}$', aid):
                return aid
    return None

def find_truth_gate_report(arxiv_id):
    """Return report dict if a validated truth_gate_report exists for this arxiv_id."""
    if not reports_dir.exists():
        return None
    for rp in reports_dir.glob("*.json"):
        try:
            r = json.loads(rp.read_text())
            if f"arxiv.org/abs/{arxiv_id}" in r.get("url", ""):
                return r
        except Exception:
            pass
    return None

def lookup_openalex(arxiv_id):
    url = f"https://api.openalex.org/works/https://doi.org/10.48550/arXiv.{arxiv_id}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": OPENALEX_UA})
        with urllib.request.urlopen(req, timeout=LOOKUP_TIMEOUT) as resp:
            if resp.status == 200:
                data = json.loads(resp.read())
                return {"id": data.get("id"), "title": data.get("title"), "cited_by_count": data.get("cited_by_count")}
    except Exception:
        pass
    return None

def lookup_inspirehep(arxiv_id):
    url = f"https://inspirehep.net/api/literature?q=arxiv%3A{arxiv_id}&size=1"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "kestrel-node/1.0"})
        with urllib.request.urlopen(req, timeout=LOOKUP_TIMEOUT) as resp:
            if resp.status == 200:
                data = json.loads(resp.read())
                hits = data.get("hits", {})
                if hits.get("total", 0) > 0:
                    hit = hits.get("hits", [{}])[0]
                    meta = hit.get("metadata", {})
                    return {"inspire_id": hit.get("id"), "citation_count": meta.get("citation_count")}
    except Exception:
        pass
    return None

n_promoted    = 0
n_needs_g1    = 0
n_needs_g23   = 0
n_no_url      = 0

print(f"\n=== 3-Gate Promotion Evaluation ===")

for item in gate["eligible_items"]:
    if item.get("review_status") == "promoted":
        continue

    item_id = item["id"]
    source_rel = item.get("source_file", "")
    source_path = staged_dir / Path(source_rel).name

    source_data = {}
    if source_path.exists() and source_path.suffix == ".json":
        try:
            source_data = json.loads(source_path.read_text())
        except Exception:
            pass

    arxiv_id = extract_arxiv_id(item, source_data)

    if not arxiv_id:
        print(f"  [NO_URL  ] {item_id[:48]}")
        print(f"              → no arxiv ID detected; Gate 1 cannot be satisfied via truth gate")
        n_no_url += 1
        continue

    # Gate 1: check truth gate report
    tgr = find_truth_gate_report(arxiv_id)
    gate1_ok = tgr is not None and tgr.get("status") == "validated"

    # Gates 2+3: two different academic API confirmations
    secondary = {}
    oa = lookup_openalex(arxiv_id)
    if oa:
        secondary["openalex"] = oa
    if len(secondary) < 2:
        ih = lookup_inspirehep(arxiv_id)
        if ih:
            secondary["inspirehep"] = ih

    n_sec = len(secondary)
    sources = list(secondary.keys())

    if gate1_ok and n_sec >= 2:
        # All 3 gates pass — promote to canonical/
        canonical_dir.mkdir(parents=True, exist_ok=True)
        canonical_data = dict(source_data) if source_data else {"id": item_id, "title": item.get("title", "")}
        canonical_data["review_status"]  = "promoted"
        canonical_data["promoted_at"]    = now_iso
        canonical_data["gate_evidence"]  = {
            "gate1": {"method": "w3m_validated", "url": tgr.get("url"), "report_id": tgr.get("candidate_id", "")},
            "gate2_3": secondary,
        }
        dest = canonical_dir / source_path.name
        dest.write_text(json.dumps(canonical_data, indent=2) + "\n")
        item["review_status"] = "promoted"
        item["promoted_at"]   = now_iso
        item["gate_evidence"] = {"gate1": "w3m_validated", "gate2_3": sources}
        print(f"  [PROMOTED] {item_id[:48]}")
        print(f"              → arxiv:{arxiv_id} | Gates: w3m + {' + '.join(sources)}")
        n_promoted += 1

    elif not gate1_ok and n_sec >= 2:
        print(f"  [NEEDS_G1] {item_id[:48]}")
        print(f"              → arxiv:{arxiv_id} | has {'+'.join(sources)}, needs w3m truth-gate validation")
        n_needs_g1 += 1

    elif gate1_ok and n_sec < 2:
        print(f"  [NEEDS_G23] {item_id[:48]}")
        print(f"              → arxiv:{arxiv_id} | w3m ok, only {n_sec} academic source(s): {sources}")
        n_needs_g23 += 1

    else:
        print(f"  [NEEDS_ALL] {item_id[:48]}")
        print(f"              → arxiv:{arxiv_id} | no gates satisfied yet; sources: {sources}")
        n_needs_g1 += 1

# ── Phase 3: Update gate flags ─────────────────────────────────────────────────

gate["auto_promote"]          = True
gate["requires_host_approval"] = False
gate["last_evaluation"]       = now_iso

with open(gate_path, "w") as f:
    json.dump(gate, f, indent=2)

print(f"\n=== Promotion Summary ===")
print(f"Promoted (all 3 gates passed):        {n_promoted}")
print(f"Has 2 academic APIs, needs w3m:       {n_needs_g1}")
print(f"Has w3m, needs 2nd academic source:   {n_needs_g23}")
print(f"No arxiv URL (non-academic items):    {n_no_url}")
print(f"\nGate flags updated: auto_promote=true, requires_host_approval=false")
INNERPY
