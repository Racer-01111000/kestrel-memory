# Extraction note — CFT DAG-based Consensus in the WAN

## Goal
Extract text from the local PDF, convert equations to LaTeX where possible, and store:
1. `canonical_math`
2. `unicode_fallback`
3. `source_span` / page reference

## Outcome so far
- PDF is text-backed, which makes extraction feasible
- full text fallback extracted to `sources/cft-dag-consensus/source-unicode-fallback.txt`
- page-separated text stored under `notes/cft-dag-consensus/pages/`
- initial staged outputs created for:
  - `classified/staged/cft-dag-consensus/canonical_math.md`
  - `classified/staged/cft-dag-consensus/unicode_fallback.md`
  - `classified/staged/cft-dag-consensus/source_span.md`

## Caveat
This is the first extraction pass. It is enough to preserve structure and begin math normalization, but not yet a full publication-grade LaTeX transcription of every formula in the paper.

## Recommended next step
Perform a deliberate page-by-page extraction sweep, especially over the ordering layer and any theorem/proof pages, to expand `canonical_math` beyond the currently recovered threshold relations and statements.
