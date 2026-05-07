# Staging Learning Scaffold

Purpose: stage learning material on this host in a separated, transfer-ready structure before offloading to the node.

This is a temporary but disciplined landing zone:
- raw material lands in `dropbox/`
- classified notes go into `knowledge/`
- project-specific material goes into `projects/`
- machine-facing ingest artifacts go into `ingest/`
- current working context goes into `runtime/`
- bundles intended for the node go into `transfer/`

## Fast path

1. Put unprocessed material in `dropbox/raw/`
2. Put lightly sorted material in `dropbox/to-classify/`
3. Promote reviewed notes into:
   - `knowledge/canonical/`
   - `knowledge/staged/`
   - `knowledge/disputed/`
   - `knowledge/speculative/`
4. Put project-bound material into `projects/<project-name>/`
5. Put files ready to move onto the node into `transfer/`

## Separation doctrine

Keep these categories distinct:
- **raw source** = original material, minimally touched
- **working notes** = summaries, extracts, claim lists
- **trusted knowledge** = reviewed/canonical material
- **project memory** = material tied to one project
- **runtime context** = active TODOs, handoff notes, current thread state
- **transfer bundle** = what will be copied to the node

Do not mix raw source and canonical truth in the same file.
Do not dump everything into MEMORY.md.
Do not silently promote staged material into canonical.

## Suggested workflow

- ingest here on host
- classify conservatively
- preserve provenance
- package for node only when structure is clean

## Directory map

- `dropbox/raw/` — untouched source material
- `dropbox/to-classify/` — material awaiting sorting
- `dropbox/to-transfer/` — selected files queued for node offload
- `projects/` — per-project folders
- `knowledge/` — cross-project knowledge by trust bucket
- `memory/` — timeline, episodic notes, semantic notes, changelog, snapshots
- `ingest/` — manifests, jsonl, queues, rules
- `runtime/` — active context and handoff notes
- `transfer/` — final transfer-ready bundles for the node
