# Node Handoff

## Context
This bundle was prepared on the host while node connectivity was unreliable. It is intended to be copied to the node once direct access is available.

## Goal
Ingest separated learning material without collapsing raw source, interpretation, and trusted knowledge into one pile.

## Bundle location
- Host path: /home/rick/.openclaw/workspace/staging-learning/transfer/learning-material-2026-04-13
- Intended node path: /home/rick/kestrel-memory/staging/learning-material-2026-04-13

## What this bundle contains
- raw sources in `bundle/raw/`
- working notes in `bundle/notes/`
- trust buckets under `bundle/knowledge/`
- project-bound material under `bundle/projects/learning-material/`

## Required behavior
- preserve directory structure
- preserve provenance
- do not silently promote staged material to canonical
- keep raw source separate from summaries
- report conflicts instead of flattening them

## Requested node actions
- [ ] copy bundle into target location
- [ ] verify file counts and structure
- [ ] stage for ingest if requested
- [ ] report duplicates, contradictions, or unclear placement

## Completion signal
Reply with the target path, file counts by folder, and any conflicts needing review.
