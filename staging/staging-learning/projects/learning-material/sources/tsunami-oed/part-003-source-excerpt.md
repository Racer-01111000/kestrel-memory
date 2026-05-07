# Source Excerpt — Tsunami OED / Bayesian inversion / LTI systems — Part 003

## Status
Raw ingested excerpt provided by Rick on 2026-04-13.
Preserved as source material. Not canonical.

## Excerpt
Fig. 5: Uncertainties of the inferred seafloor displacement field, illustrated as pointwise standard deviations, for different
sensor counts, |S| ∈ {10, 25, 50, 75, 100, 125, 150, 175}, during the greedy sensor selection algorithm. Hyperlink to animation
of evolving uncertainty field during greedy sensor selection, at each iteration, k = 1, 2, . . . , 175.
information gain from placing sensors according to the greedy
optimization algorithm. We note that for this linear inverse
problem, the posterior covariance Γpost is independent of
the observed data during an earthquake.3 As a result, the
sensor selection algorithm seeks to reduce uncertainty in the
inferred parameter field over the whole domain uniformly.
If we are instead interested in reducing uncertainties in a
specific spatiotemporal region (motivated, perhaps, by models
of potential rupture scenarios), the masking strategy described
in Section III-G2 can be used to readily incorporate this
information into the sensor selection procedure.
V. CONCLUSIONS
In this paper, we presented a highly scalable, distributed-
memory framework for solving extreme-scale Bayesian D-
optimal design problems governed by LTI dynamical systems.
By recasting the objective from the billion-dimensional pa-
rameter space to the O(105)-dimensional data space, we con-
3In this linear inverse problem, the uncertainties are informed by the
mapping between the seafloor motion parameters and the pressure observables
at sensor locations, which is governed by the dynamics of coupled acoustic–
gravity wave propagation in the varying-depth ocean. Additional factors that
enter the uncertainty calculations are the assumptions on the likelihood, noise
model, and prior (see Section II).
verted the otherwise intractable Bayesian OED problem into a
practically computable combinatorial matrix subset selection
problem. To make the computation of the Bayesian OED
solution efficient at extreme scale, we designed a greedy Schur
complement update-based algorithm; this approach eliminates
redundant dense matrix factorizations, minimizes memory
footprint, and is co-designed to map naturally onto mas-
sively parallel GPU architectures. We also developed an MPI-
PyTorch implementation of this algorithm that uses a double-
buffered pipelined approach to completely overlap I/O with
GPU computation. The resulting multi-GPU sensor selection
algorithm is performance-portable and exhibits excellent weak
and strong scalability over a 128× increase in the number
of GPUs on leadership-class supercomputers with varying
hardware and filesystem architectures.
We applied this framework to a physics-based, data-driven
digital twin for tsunami early warning in the CSZ. The
framework selected an optimal 175-sensor network from 600
candidate locations in just 1.5 hours on 16 NVIDIA A100
GPUs, solving a Bayesian OED problem that minimizes the
uncertainties of the inferred seafloor motion, a parameter field
that is discretized with over 1 billion degrees of freedom. To
our knowledge, this is the first time that a PDE-constrained
Bayesian OED problem has been solved at such a large
scale without the use of reduced-order modeling, surrogate
modeling, or other approximations of the high-fidelity PDE
model. The structure-exploiting design of the algorithm makes
the problem tractable; the optimized, pipelined, multi-GPU
implementation enables an efficient and scalable solution.
Deploying offshore instrumentation across the Pacific
Northwest represents a massive, long-term infrastructure in-
vestment. By designing algorithms that exploit problem struc-
ture and leverage multi-GPU-accelerated computing, we were
able to transform a large-scale Bayesian OED sensor selec-
tion problem from a computationally prohibitive task into
an agile, iterative design tool. This OED framework can be
used to rapidly evaluate competing network configurations—
targeting different sensor budgets, limited sensor deployments
in specific areas, non-uniform sensor cost models, or varying
instrument noise characteristics—thereby providing the com-
putational tools for guiding future sensor deployments through
mathematically rigorous, uncertainty-aware optimization
