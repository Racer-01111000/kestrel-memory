# Canonical Math — Finding Nemo-Nemo: CFT DAG-based Consensus in the WAN

## Status
Initial math-oriented extraction from the local PDF on 2026-04-13.
Use this as a staged math layer, not yet a fully verified final transcription.

## Source PDF
`/home/rick/Downloads/learning/CFT DAG-based Consensus in the WAN.pdf`

## Equation/style policy
- `canonical_math` stores LaTeX-style normalization where the equation can be recovered confidently from the PDF text layer
- `unicode_fallback` remains the conservative readable fallback
- `source_span` records page provenance

## Recovered / normalized expressions so far

### Fault threshold
```latex
n = 2f + 1
```
Meaning: the protocol assumes `n` replicas with up to `f` crash faults.

### Direct-commit threshold on the DAG
```latex
f + 1
```
Observed in prose as the threshold of blocks referencing a leader/skeleton proposal for direct commitment.

### Classical BFT-to-CFT threshold shift
```latex
2f + 1 \to f + 1
```
Observed in prose describing the adaptation from Mysticeti/BFT-style thresholds to CFT thresholds.

### Atomic broadcast order statement shape
Readable normalized form from the system model:
```latex
\text{If } p \text{ commits } v_1 \text{ before } v_2,
\text{ then } q \text{ commits } v_1 \text{ before } v_2.
```

### Random asynchronous liveness / agreement statement
Readable normalized form from the system model:
```latex
\Pr[\text{validity and agreement}] = 1
```
More precisely: validity and agreement hold with probability 1 (almost surely).

## Not yet fully lifted into canonical LaTeX
These likely need a more deliberate page-by-page pass:
- full pseudocode blocks
- any formal theorem / proof statements later in the paper
- figure-embedded equations or threshold relations not cleanly exposed by `pdftotext`
- any notation introduced in sections beyond the currently sampled pages

## Next pass recommendation
Do a page-by-page math sweep over:
- system model assumptions
- ordering layer / commit rule sections
- any theorem / lemma / proof sections
- evaluation formulas if present
