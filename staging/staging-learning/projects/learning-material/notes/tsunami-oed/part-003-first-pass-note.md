# First-pass note — Tsunami OED excerpt — Part 003

## Classification
- source_class: external_research excerpt supplied by Rick
- learning_stage: claim / early technical source fragment
- storage_class: staged
- canonical_status: not canonical

## Main takeaways in this part
- Figure 5 appears to visualize uncertainty reduction as greedy-selected sensors accumulate
- in this linear inverse setting, posterior covariance is independent of the realized earthquake data
- default selection therefore reduces uncertainty uniformly over the parameter field
- the earlier masking / weighting strategy can target uncertainty reduction to specific spatiotemporal regions
- conclusion claims the key tractability move is recasting from billion-dimensional parameter space to roughly O(10^5)-dimensional data space
- conclusion emphasizes the greedy Schur-complement update plus pipelined MPI-PyTorch implementation as the enabling computational design
- reported end-to-end application result: 175 optimal sensors selected from 600 candidates in ~1.5 hours on 16 A100 GPUs
- problem size emphasized as >1 billion degrees of freedom in the seafloor-motion parameter field
- authors claim this is the first PDE-constrained Bayesian OED solve at this scale without reduced-order / surrogate approximations
- framework is positioned as a practical design tool for evaluating sensor budgets, placement constraints, cost models, and noise assumptions

## Why this chunk matters
This closes the narrative arc of the paper:
- the math reformulation makes the problem computable
- the algorithmic update structure makes it cheaper
- the systems design makes it scalable
- the tsunami digital-twin case makes it operationally meaningful

## Cautions
- novelty claim ('first time at such a large scale') should be treated as author claim until independently checked
- conclusion compresses many earlier assumptions; do not promote summary claims without preserving those assumptions
- exact citation metadata is still missing from the staged record

## Likely durable themes if the full paper checks out
- data-space reformulations can unlock otherwise intractable Bayesian design problems
- structure-exploiting dense linear algebra plus I/O overlap can turn giant offline design problems into iterative engineering tools
- digital-twin sensor design can be framed as uncertainty-aware network optimization rather than ad hoc placement
