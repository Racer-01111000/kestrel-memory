# First-pass note — Tsunami OED excerpt — Part 001

## Classification
- source_class: external_research excerpt supplied by Rick
- learning_stage: claim / early technical source fragment
- storage_class: staged
- canonical_status: not canonical

## What this excerpt appears to cover
- GPU-portable implementation details across AMD and NVIDIA
- zero-allocation in-place memory management
- parallel POSIX I/O and double-buffered overlap of I/O with compute
- weak and strong scaling on leadership-class supercomputers
- application to a Cascadia Subduction Zone digital twin
- greedy sensor selection for tsunami early warning
- Bayesian inversion / Bayesian OED for LTI dynamical systems
- Gaussian prior/noise assumptions producing Gaussian posterior
- posterior mean and covariance expressions
- computational challenge of solving the posterior system at extreme scale
- offline/online split with adjoint precomputation and FFT/GPU acceleration

## Likely value
This looks useful for:
- extreme-scale inference methods
- PDE-constrained Bayesian inversion
- sensor placement / optimal experimental design
- tsunami early warning digital twins
- HPC implementation patterns for inverse problems

## Cautions
- excerpt begins mid-sentence, so implementation context is incomplete
- source bibliographic metadata is not yet attached
- mathematical notation is partial and should be checked against the full paper
- no claims here should be promoted without fuller source context

## Next desirable ingest items
- full citation / title / authors / venue / year
- abstract and conclusion
- algorithm section on greedy sensor selection
- implementation section on overlap, buffering, and scaling
- application section on CSZ sensor optimization
