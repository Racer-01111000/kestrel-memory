#!/usr/bin/env python3
"""
Kestrel persona enrichment — w3m + Merriam-Webster.
Reads phrases.txt and words.txt, fetches definitions, writes structured JSON.

HARD RULES:
- Never touches research validation pipeline
- Never writes to ~/NODE/ or training/
- Never calls Semantic Scholar
- Integration point: kestrel_persona.py ONLY
"""
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

BASE = Path.home() / "kestrel-memory" / "persona"
CORPUS_DIR = BASE / "phrase_corpus"
PHRASES_FILE = BASE / "phrases.txt"
WORDS_FILE = BASE / "words.txt"
PROGRESS_FILE = BASE / "enrich_progress.json"

SLEEP_BETWEEN = 2
MAX_TEXT_BYTES = 12000
CORPUS_DIR.mkdir(parents=True, exist_ok=True)

MORAL_KEYWORDS = [
    "moral", "ethic", "value", "virtue", "justice", "right", "wrong",
    "truth", "honest", "integrity", "trust", "duty", "respect", "harm", "fair"
]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_progress() -> set:
    if PROGRESS_FILE.exists():
        return set(json.loads(PROGRESS_FILE.read_text()).get("completed", []))
    return set()


def save_progress(completed: set) -> None:
    PROGRESS_FILE.write_text(json.dumps(
        {"completed": sorted(completed), "updated_at": utc_now()}, indent=2))


def w3m_fetch(url: str) -> str:
    try:
        result = subprocess.run(
            ["w3m", "-dump", "-T", "text/html", "-o", "display_link=0", url],
            capture_output=True, text=True, timeout=20
        )
        return result.stdout[:MAX_TEXT_BYTES]
    except Exception:
        return ""


def merriam_webster_url(term: str) -> str:
    return "https://www.merriam-webster.com/dictionary/" + quote(term, safe="")


def parse_merriam_webster(text: str, term: str) -> tuple[str, str]:
    """Returns (definition, usage_example) from w3m Merriam-Webster dump.

    MW w3m output has definition lines starting with ': ' after a numbered
    section marker. The first such line is the primary sense.
    """
    if not text:
        return "", ""

    lines = text.splitlines()
    definition = ""
    usage = ""

    # MW definitions are lines starting with ": " — the first one is primary
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(":") and len(stripped) > 3 and not stripped.startswith(":["):
            raw = stripped[1:].strip()
            definition = raw.split(" : ")[0].rstrip(" :")
            # Look ahead for a usage example: a short multi-word phrase on the next few lines
            for j in range(i + 1, min(i + 8, len(lines))):
                ex = lines[j].strip()
                if (ex and not ex.startswith(":") and not ex.startswith("[")
                        and not ex.startswith("□") and not ex.startswith("☆")
                        and not ex.startswith("—") and len(ex) > 8 and " " in ex):
                    usage = ex
                    break
            break

    return definition, usage


def moral_weight(term: str, definition: str) -> str:
    combined = (term + " " + definition).lower()
    if any(kw in combined for kw in MORAL_KEYWORDS):
        return "moral/ethical weight present"
    return "neutral"


def enrich_term(term: str, source: str) -> dict:
    url = merriam_webster_url(term)
    text = w3m_fetch(url)
    definition, usage = parse_merriam_webster(text, term)

    return {
        "term": term,
        "source_list": source,
        "definition": definition if definition else "(not found in Merriam-Webster)",
        "usage_context": usage,
        "moral_weight": moral_weight(term, definition),
        "source_url": url,
        "enriched_at": utc_now(),
        "corpus_layer": "kestrel_persona_corpus"
    }


def safe_filename(term: str) -> str:
    return term.replace(" ", "_").replace("'", "").replace("/", "_")[:80]


def main():
    completed = load_progress()
    entries = []
    for line in PHRASES_FILE.read_text().splitlines():
        t = line.strip()
        if t:
            entries.append((t, "phrases"))
    for line in WORDS_FILE.read_text().splitlines():
        t = line.strip()
        if t:
            entries.append((t, "words"))

    total = len(entries)
    remaining = [(t, s) for t, s in entries if t not in completed]
    print(f"[kestrel_persona_enrich] total={total} completed={len(completed)} remaining={len(remaining)}", flush=True)

    for i, (term, source) in enumerate(remaining):
        record = enrich_term(term, source)
        fname = CORPUS_DIR / f"{safe_filename(term)}.json"
        fname.write_text(json.dumps(record, indent=2, ensure_ascii=False))
        completed.add(term)
        if (i + 1) % 20 == 0:
            save_progress(completed)
            print(f"[kestrel_persona_enrich] progress {len(completed)}/{total}", flush=True)
        time.sleep(SLEEP_BETWEEN)

    save_progress(completed)
    print(f"[kestrel_persona_enrich] done — {len(completed)} records in phrase_corpus/", flush=True)


if __name__ == "__main__":
    main()
