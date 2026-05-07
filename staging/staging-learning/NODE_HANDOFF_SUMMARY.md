# Node Handoff Summary

## Status
This staging tree was offloaded from the host on 2026-04-13.
Target path:
- `/home/rick/kestrel-memory/staging/staging-learning/`

This bundle is intended as a human-first, provenance-aware staging area for later ingestion, curation, and promotion.

## What was offloaded

### 1. Host-side staging scaffold
A structured staging system was copied over, including:
- `README.md`
- `INDEX.md`
- `runtime/ACTIVE_CONTEXT.md`
- `dropbox/`
- `projects/`
- `knowledge/`
- `memory/`
- `ingest/`
- `transfer/`

Purpose:
- keep raw source, notes, trust buckets, manifests, and transfer bundles separated
- avoid mixing source material and canonical truth

### 2. Learning-material project scaffold
Under:
- `projects/learning-material/`

This includes:
- `PROJECT.md`
- `STATE.md`
- `DECISIONS.md`
- `OPEN_QUESTIONS.md`
- `TASK_LEDGER.md`
- workflow folders such as `sources/`, `notes/`, `classified/`, `handoffs/`, `exports/`, `incoming/`

### 3. First transfer bundle
Under:
- `transfer/learning-material-2026-04-13/`

This contains:
- transfer README
- handoff note
- manifests
- bundle skeleton for raw, notes, knowledge buckets, and project-bound material

### 4. Operator doctrine package
This package preserves Rick's operator doctrine text and split derivatives.

Primary locations:
- source: `projects/learning-material/sources/operator-doctrine/`
- notes: `projects/learning-material/notes/operator-doctrine/`
- staged derivatives: `projects/learning-material/classified/staged/`

Important files:
- full source doctrine text
- evaluation note
- `operator_profile.md`
- `response_doctrine.md`
- `ethics_module.md`
- `live_response_rules.md`
- handoff and manifest files

Use:
- preserve the full human-authored source
- use derivatives for runtime-aligned reference
- do not collapse the source and derivative layers together

### 5. Tsunami OED paper staging
Under:
- `projects/learning-material/sources/tsunami-oed/`
- `projects/learning-material/notes/tsunami-oed/`

Current state:
- earlier part-by-part source excerpts still exist as fallback provenance
- a cleaner consolidated text source was staged as the primary text source:
  - `source-consolidated-v2.md`
- a consolidated note was added:
  - `consolidated-v2-note.md`

Important caution:
- text copy is better than before but still contains OCR/markup debris
- screenshots/figure context existed in chat context and informed staging, but this node tree primarily contains the text-side staging artifacts

### 6. CFT DAG consensus PDF extraction package
Paper:
- `Finding Nemo-Nemo: CFT DAG-based Consensus in the WAN`

Source PDF path on host was:
- `/home/rick/Downloads/learning/CFT DAG-based Consensus in the WAN.pdf`

Extracted/staged under:
- `projects/learning-material/sources/cft-dag-consensus/`
- `projects/learning-material/notes/cft-dag-consensus/`
- `projects/learning-material/classified/staged/cft-dag-consensus/`

Important files:
- `source-unicode-fallback.txt`
- page-separated text under `notes/cft-dag-consensus/pages/`
- `extraction-note.md`
- `canonical_math.md`
- `unicode_fallback.md`
- `source_span.md`

Current truth:
- this is a first-pass extraction package
- useful and structured, but not yet a full publication-grade equation transcription

## Operational truths worth remembering
- The host-side doctrine strongly emphasizes: never fake execution, preserve continuity, separate scopes, and label machine targets clearly.
- Earlier in the day, a networking confusion was resolved: `ssh node` on the host had been a LAN alias, not proof of Tailscale reachability.
- The node's live LAN address at offload time was `192.168.1.32`.
- Offload succeeded over LAN to this node path.

## Recommended next actions for future Kestrel on the node
1. Read:
   - `README.md`
   - `INDEX.md`
   - `runtime/ACTIVE_CONTEXT.md`
   - this file
2. Review the operator doctrine package before making behavior-sensitive changes.
3. Treat tsunami OED and CFT DAG materials as staged source/notes, not canonical truth.
4. If doing deeper ingest work:
   - keep provenance visible
   - prefer markdown truth first, machine-ingest second
   - preserve source_span/page references when extracting equations or formal claims
5. If promoting any material:
   - separate source claims from verified canonical facts
   - use trust buckets conservatively

## Short summary
This staging tree is a structured offload from the host containing:
- the learning scaffold
- the operator doctrine package
- the tsunami OED paper staging
- the CFT DAG PDF extraction package

It is ready for careful node-side review, refinement, and later promotion — not blind ingestion.
