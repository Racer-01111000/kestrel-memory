# First-pass note — Tsunami OED excerpt — Part 002

## Classification
- source_class: external_research excerpt supplied by Rick
- learning_stage: claim / early technical source fragment
- storage_class: staged
- canonical_status: not canonical

## Main technical content in this part
- Hessian re-expressed in data space via Sherman–Morrison–Woodbury
- data-space Hessian `K = Γnoise + FG*` as the main dense object
- offline cost dominated by adjoint PDE solves for the candidate sensor superset
- online evaluation made fast once the candidate-set adjoints exist
- D-optimal design framed as maximizing expected information gain / KL divergence
- D-optimal objective reduced to data-space log-determinant forms
- isotropic-noise simplification reduces objective to `-log det(KS)`
- greedy sensor subset selection used because exact combinatorial solve is NP-hard
- block Cholesky / Schur-complement updates reduce per-candidate cost from O(k^3 Nt^3) to O(k^2 Nt^3)
- candidate evaluations parallelized across GPUs / ranks
- dense matrix K stored as chunked HDF5 with independent POSIX I/O
- double-buffering plus async H2D transfers plus CUDA/HIP streams hide I/O behind compute
- recomputation of the winning candidate avoids broadcasting large blocks
- globally preallocated Cholesky factor eliminates dynamic allocation in the inner loop
- objective can be modified for sensor-cost weighting and nonuniform uncertainty weighting
- D-optimal objective is submodular, giving the greedy result a (1 - 1/e) approximation guarantee
- lazy greedy is rejected as a poor fit for this distributed architecture because of synchronization bottlenecks
- implementation uses PyTorch + mpi4py and does candidate-loop linear algebra in float32 while keeping K on disk in float64
- single-GPU benchmarks show Schur formulation far outperforming naive refactorization
- distributed scaling reported as near-ideal on Perlmutter and Frontier
- CSZ digital-twin application: 600 candidates, budget 175, large offline precompute, then relatively fast greedy selection

## Notable implementation patterns
- strict in-place operations
- zero-allocation inner loop
- overlap of storage I/O, PCIe transfer, and GPU compute
- HDF5 chunking tuned for scattered access
- file-locking and chunk-cache tuning for performance
- modulo indexing trick for scaling experiments with manageable stored matrix size

## Notable application numbers mentioned
- candidate matrix K stored as ~464 GB chunked HDF5 dataset
- strong/weak scaling up to hundreds of GPUs / over a thousand GCDs
- 600 adjoint PDE solves computed in ~500 hours on 512 A100 GPUs
- forming G* and K took ~3 hours on 512 A100 GPUs
- greedy sensor selection on K took ~1.5 hours on 16 A100 GPUs
- greedy 175-sensor configuration significantly outperformed 100 random 175-sensor configurations

## Cautions
- excerpt is still partial and bibliographic metadata is incomplete
- equations and notation should be reconciled against the full paper before promotion
- benchmark claims and performance numbers should be treated as source claims until independently checked or better contextualized

## Likely value
This source looks especially relevant for:
- extreme-scale Bayesian OED
- HPC-aware greedy selection algorithms
- digital-twin sensor network optimization
- architecture-portable GPU implementations
- practical methods for hiding I/O in large dense-matrix workflows
