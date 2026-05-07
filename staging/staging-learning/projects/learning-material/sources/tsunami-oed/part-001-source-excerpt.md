# Source Excerpt — Tsunami OED / Bayesian inversion / LTI systems — Part 001

## Status
Raw ingested excerpt provided by Rick on 2026-04-13.
Preserved as source material. Not canonical.

## Excerpt
mance portability across both AMD and NVIDIA GPU
architectures. By utilizing strict zero-allocation in-place
memory management, parallel POSIX I/O, and a double-
buffered architecture with isolated compute streams,
the framework completely overlaps I/O with computa-
tion. The implementation exhibits excellent weak and
strong scalability on leadership-class supercomputers
with varying architectures.
3) Application to digital twin for tsunami early warn-
ing: We demonstrate the efficacy of the proposed al-
gorithms on an extreme-scale digital twin of the CSZ
with over 1 billion degrees of freedom in the parameter
field. We optimize a 175-sensor network from a pool of
600 candidates to provide the maximum reduction in the
uncertainties of the inferred parameters that describe the
earthquake-induced seafloor motion. This paves the way
for the cost-effective, real-world deployment of offshore
early warning networks.
The remainder of this paper is organized as follows. Sec-
tion II introduces the mathematical and computational formu-
lations of Bayesian inverse problems for LTI systems. Sec-
tion III details the greedy sensor selection algorithm, showing
theoretical properties and highlighting parallel implementation
details. Sections IV-A to IV-C present single-GPU perfor-
mance and distributed parallel scaling results across multiple
supercomputer architectures. Finally, Section IV-D applies the
framework to the CSZ digital twin to derive optimal sensor
placements for tsunami early warning.
II. BACKGROUND
The algorithms developed in this paper address Bayesian
OED for inverse problems governed by LTI dynamical sys-
tems. In this section, we provide an introduction to Bayesian
inverse problems in this context and briefly describe a frame-
work for efficiently computing solutions to these problems.
The methods described here are based on the work by Hen-
neking et al. [27].
A. Bayesian inverse problems for LTI systems
Mathematical models of wave propagation, transport, diffu-
sion, and numerous other physical phenomena often take the
form of LTI dynamical systems. In many cases, the input pa-
rameters to these models, here denoted by m, appear linearly
in the governing equations (e.g., as boundary or volumetric
sources). At the same time, the model observables (e.g.,
observations of states at discrete sensor locations) are typically
related to the PDE solution via a linear observation operator.
If these conditions are true, the parameter-to-observable (p2o)
map, denoted by F : m 7 → d, which maps the parameters m to
the observables d via the PDE solution, also represents an LTI
system. In that case, both F and its adjoint F∗ are time-shift-
invariant; a temporal shift in the inputs (parameters) yields an
identical shift in the outputs (observables). As a result, the
discretized operators F and F∗ are block-triangular Toeplitz
matrices [28].
The primary objective in Bayesian inversion is to charac-
terize the posterior probability distribution of the unknown
model parameters m given the (noisy) observational data
dobs. Formulated in a discrete setting, Bayes’ theorem states
πpost(m|dobs) ∝ πlike(dobs|m)πprior(m), i.e., the posterior
distribution of m is proportional to the product of the likeli-
hood function and the prior distribution.
Assuming an additive, zero-mean Gaussian observational
noise model with covariance matrix Γnoise and a zero-mean
Gaussian prior with covariance Γprior, the posterior (see [31])
is also a Gaussian, πpost ∼ N (mmap, Γpost), where

F∗Γ−1
noiseF + Γ−1
prior

mmap = F∗Γ−1
noisedobs, (1)
and Γpost := H−1 =

F∗Γ−1
noiseF + Γ−1
prior
−1
. (2)
B. Efficient computational methods for LTI systems
While it is easy to write down the expressions for the pos-
terior mean and covariance in Equations (1) and (2), actually
solving the linear system in Equation (1) is computationally
challenging for high-dimensional problems. This effect is com-
pounded for problems governed by hyperbolic systems, where
the Hessian H lacks exploitable low-rank structure. However,
efficient methods have recently been developed in [7] and [27]
that enable real-time Bayesian inference for extreme-scale LTI
systems.
Within this real-time inversion framework, the inverse prob-
lem is partitioned into a set of computationally intensive
offline precomputations and a rapid online phase for parameter
inference. The offline phase primarily consists of computing
adjoint PDE solutions, 1 per sensor location. After this setup
phase, subsequent matrix–vector products with the discrete
p2o map F are computed using efficient, FFT-based, GPU-
accelerated algorithms that achieve
