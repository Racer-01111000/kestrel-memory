# Transfer Bundle: learning-material-2026-04-13

Status: ready for population

## Purpose
This is the first host-side transfer bundle for learning material that will later be offloaded to the node.

## Structure
- `bundle/raw/` — untouched source material selected for transfer
- `bundle/notes/` — summaries, extracts, claim lists, and working notes
- `bundle/knowledge/canonical/` — reviewed durable material safe to rely on
- `bundle/knowledge/staged/` — useful but not fully verified material
- `bundle/knowledge/disputed/` — conflicting or unresolved material
- `bundle/knowledge/speculative/` — theories and future branches
- `bundle/projects/learning-material/` — project-bound files for the node
- `handoff/` — instructions for the node
- `manifests/` — provenance and transfer accounting

## Ready-to-use flow
1. drop source files into the matching bundle folders
2. keep summaries separate from raw source
3. update the manifest
4. update the handoff note
5. move only this bundle to the node when connected
