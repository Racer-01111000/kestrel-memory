# Source Excerpt — Tsunami OED / Bayesian inversion / LTI systems — Consolidated v2

## Status
Cleaner consolidated source provided by Rick on 2026-04-13.
This supersedes the earlier part-split text excerpts as the primary staged text source.
Screenshots/figure-derived context remain preserved separately.
Not canonical.

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
/span>
F∗Γ−1
noiseF + Γ−1
prior
/span>
mmap = F∗Γ−1
noisedobs, (1)
and Γpost := H−1 =
/span>
F∗Γ−1
noiseF + Γ−1
prior
/span>−1
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
adjoint PDE solutions, one per sensor location. After this setup
phase, subsequent matrix–vector products with the discrete
p2o map F are computed using efficient, FFT-based, GPU-
accelerated algorithms that achieve O105/span>× speedups over
traditional PDE solves [28], [32].
A critical component of the inversion framework in [27] is
the re-expression of the Hessian in the data space using the
Sherman–Morrison–Woodbury identity:
Γpost = Γprior − G∗K−1G/span> ,
where K := Γnoise + FG∗ and G∗ := ΓpriorF∗. The matrix K
is termed the “data-space Hessian,” with dimension NdNt ×
NdNt, where Nd is the number of sensors, and Nt is the
number of timesteps. It can be explicitly formed as a dense
matrix using the fast, FFT-based algorithms [27].
Thus, the dominant cost of the Bayesian inversion frame-
work lies in computing the Nd adjoint PDE solutions that
define F. While each of these solves can take hours on
hundreds of GPUs for large-scale problems, this is a one-
time, offline setup cost. Moreover, once the adjoint PDE
solutions have been computed for a superset of candidate
sensor locations, inversions can be quickly evaluated using
any smaller subset of those locations. This enables us to ask
the core question of this paper: given a fixed sensor budget,
what are the optimal locations to select?
In the remainder of the paper, we explore how this com-
putational framework can be leveraged to facilitate Bayesian
OED for extreme-scale systems. We then demonstrate how
this framework enables the optimal design of seafloor sensor
networks for the CSZ and allows for seamless integration of
expert knowledge or practical cost constraints.
III. METHODS
We formalize the OED problem as an optimization problem
that seeks to maximize the expected information gain (EIG)
from data. The information gain is measured by the Kullback–
Leibler (KL) divergence [33] of the prior to the posterior.
For a linear inverse problem with Gaussian prior, Gaussian
likelihood, and additive Gaussian noise, the problem of max-
imizing the EIG is equivalent to the problem of D-optimal
experimental design [23]. D-optimality seeks to minimize
the determinant of the posterior covariance matrix. Another
popular criterion is A-optimality, which minimizes the aver-
age posterior variance (the trace of the posterior covariance
matrix) [21], [34].
In this work, we focus on the D-optimal criterion primarily
for two reasons. First, it possesses a clear information-theoretic
interpretation as the KL divergence between the posterior and
prior distributions. Second, as we will see in Section III-H, the
resulting objective function for OED is submodular, making
it an ideal choice for the greedy algorithm employed here.
Thus, the remainder of the paper focuses on designing efficient
algorithms for D-optimal experimental design for Bayesian
inverse problems governed by LTI dynamical systems.
A. D-optimal sensor subset selection
Suppose we have a set C of candidate sensors. Given a
budget B < |C|, the goal of D-optimal sensor subset selection
is to choose the set Sopt ⊂ C of size |Sopt| ≤ B that minimizes
the log-determinant of the posterior covariance. That is, we
aim to find
Sopt := arg min
S⊂C,|S|≤B
Φ(S) := log det((Γpost)S ), (3)
where (Γpost)S is the posterior covariance obtained using only
information from the sensors in S.
B. Notation
Throughout the rest of the paper, we use the subscript S to
denote operators that contain only information from the sen-
sors in S. For example, FS and GS are block-row subsampled
versions of F ≡ FC and G ≡ GC , respectively. Similarly, KS
is block-row and block-column subsampled from K ≡ KC .
For F, G, and K, the subsampled operators can be formed
by directly subsampling the respective full operators along
the appropriate dimensions. However, an operator such as
(Γpost)S , which involves the inverse of subsampled operators,
must be formed from its expression in Section II-B using the
subsampled operators FS , GS , and KS . Importantly, (Γpost)S
is not equal to a subsampled version of the corresponding full
operator Γpost ≡ (Γpost)C .
C. Computable D-optimal objective function
The D-optimal objective function in the form of Equa-
tion (3) is not directly computable for high-dimensional pa-
rameter fields, where forming the covariance matrix Γpost is
intractable. Instead, we reformulate the D-optimal objective
function in the (lower-dimensional) data space by using the
matrix determinant lemma [35]:
det((Γpost)S ) = det Γprior − G∗
S K−1
S GS
/span>
= det(Γprior) detK−1
S
/span> det ((Γnoise)S ).
Thus, the D-optimality objective reduces to
Φ(S) = − log det(KS ) + log det((Γnoise)S ). (4)
Moreover, with the added assumption of isotropic noise (i.e,
Γnoise = γ2I), the D-optimality objective becomes
Φ(S) = − log det(KS ). (5)
Given the full matrices K and Γnoise, evaluating the D-
optimal objective then becomes computationally efficient
when the data space is of a much lower dimension than
the parameter space. For a given sensor subset S ⊂ C,
these matrices can be directly subsampled to form KS and
(Γnoise)S , respectively. The log determinants can be computed
via Cholesky factorization.
Note that an equivalent formulation of the D-optimal design
problem is given by defining ˜Φ := −Φ and solving
Sopt := arg max
S⊂C,|S|≤B
˜Φ(S) (6)
instead. This is the approach used in the remainder of the
paper.
D. Greedy algorithm for computing D-optimal design
While the computable forms of the objective in Equa-
tions (4) and (5) can be efficiently evaluated, the combinatorial
optimization problem in Equation (6) is NP-hard [36], [37].
We employ a greedy algorithm for approximating the solution
to this optimization problem. Given a budget B and a matrix
K for a candidate sensor set C, the greedy algorithm builds
the (approximate) optimal sensor set Sopt iteratively. Let Sk
opt
be the greedy-optimal sensor set at iteration k. At iteration
k + 1, sensor s is added to Sk
opt if it provides the maximum
information gain to the current sensor selection, i.e., if it
maximizes ˜ΦSk
opt ∪ {s}/span> − ˜ΦSk
opt
/span> among all sensors in
C \ Sk
opt.
Evaluating ˜ΦSk
opt ∪ {s}/span> for each of the candidate sensors
s ∈ C \ Sk
opt involves calculating the log-determinants of
the “test matrices” KSk
opt∪{s}. The determinants are evaluated
using Cholesky factorization. However, instead of refactorizing
the test matrix from scratch for each candidate sensor, a block
Cholesky update algorithm is used. The algorithm, assuming
isotropic noise, is given in Algorithm 1. It can easily be
modified for the anisotropic noise case.
E. Algorithmic complexity
The computational efficiency of the greedy selection process
is dependent on how the information gain is evaluated for each
candidate. After k iterations of the algorithm, the (k + 1)-th
iteration evaluates the |C| − k remaining candidate sensors.
For each candidate s, the test matrix KSk
opt∪{s} is formed by
augmenting KSk
opt with the dense block rows and columns
of K corresponding to s; the resulting test matrix has size
(k + 1)Nt × (k + 1)Nt. A naive implementation that evaluates
the objective function by refactorizing the test matrix from
scratch requires O(k3N 3
t ) floating-point operations per candi-
date. Summed over the full selection budget B, this approach
scales with a cumulative complexity of O(|C|B4N 3
t ).
By leveraging the block Cholesky update and the Schur
complement, the optimized formulation strictly avoids redun-
dant factorizations. Because the Cholesky factor LS from
iteration k − 1 is reused, evaluating a new candidate only
requires solving a lower-triangular system via forward substi-
tution. This step dominates the per-candidate cost, requiring
only O(k2N 3
t ) operations. Consequently, the block update
strategy reduces the total algorithmic complexity across the
entire selection process to O(|C|B3N 3
t ), effectively lowering
the computational cost by a factor equal to the number of
budgeted sensors—which can be very large.
F. Multi-GPU implementation and memory optimizations
As the evaluation of candidate sensors is embarrassingly
parallel, Algorithm 1 can be easily extended to incorporate
distributed memory parallelism. First, the candidate sensor
evaluations are distributed among the processors participating
in the computation. At each iteration, once the next sensor
has been found, the optimal score value dmax and the in-
teger index of the selected sensor are communicated to all
processors. Then, the processors update their local copies of
LS accordingly. This strategy, while incurring some redundant
computation, avoids the expensive communication of the LS
matrix over the network. In addition, all linear algebra oper-
ations are performed strictly in-place to minimize the GPU
memory footprint, as this is the primary factor constraining
the maximum sensor budget B.
Each candidate evaluation in Algorithm 1 consists of two
main phases: reading the required matrix blocks from the
full K matrix and computing the objective function to get
the score value ds for candidate sensor s. As the processors
independently evaluate candidates, they execute thousands of
scattered read requests to fetch the non-contiguous Nt × Nt
blocks required to build the test columns KS,s. At iteration k,
for each candidate s, k blocks must be fetched from memory.
To maximize network bandwidth and avoid the metadata
lock contention that traditionally throttles collective access on
parallel file systems [38]–[40], the dense covariance matrix
K is stored as a 2D-chunked HDF5 dataset and accessed via
independent parallel POSIX I/O [41]–[43]. This implementa-
tion was found to deliver better performance than independent
or collective MPI-IO thanks to decreased latencies on the
scattered access pattern.
Crucially, the implementation was designed to maximize
overlap of I/O with computations: after the CPU retrieves the
data for one candidate from the file system, it initiates an
asynchronous host-to-device memory transfer to move the data
to the GPU. The GPU then performs the necessary objective
function evaluation for that candidate. In the meantime, the
CPU issues another set of read requests to fetch the next
candidate from the file, using a double-buffered framework.
Furthermore, this system is coupled with isolated CUDA/HIP
streams to create a fully overlapped, asynchronous execution
pipeline: while the CPU thread executes a blocking POSIX
read of candidate s + 1 from the file system into pinned
host memory, a dedicated GPU stream concurrently dispatches
the non-blocking host-to-device (H2D) PCIe transfer and the
dense in-place objective function calculations for candidate
s. Fine-grained CUDA/HIP events synchronize the pipeline
stages to prevent race conditions, ensuring that I/O and mem-
ory transfers are entirely hidden behind the execution of the
GPU computations.
Following this inner loop of candidate evaluations, an
MPI_Allreduce operation is used to synchronize the ranks
and determine the global maximum dmax and corresponding
sensor index s∗
global. Because the dense matrix components
were intentionally discarded to avoid broadcasting large blocks
over the network, a recomputation phase is inserted im-
mediately before the global state update. Every rank inde-
pendently re-reads the data for s∗
global and re-executes the
forward substitution and Schur complement specifically for
the global maximizer. This synchronous recomputation enables
all workers to execute the block Cholesky update in parallel,
ensuring that each rank maintains an identical, up-to-date copy
of the global factor LS without overwhelming the interconnect
bandwidth.
To further accelerate the GPU execution, the algorithm relies
on a globally pre-allocated Cholesky factor. Since the final
sensor budget B is known a priori, the absolute maximum
memory footprint of the lower-triangular factor LS is bounded
by a (BNt) × (BNt) block matrix. This buffer is allocated
on the accelerator once during initialization. During iteration
k, the parallel workers operate exclusively on a kNt × kNt
tensor view of this contiguous block. This zero-allocation
inner loop prevents GPU memory fragmentation and entirely
eliminates the latency of dynamic memory allocation during
the computationally intensive candidate evaluation phase.
G. Modifications to the D-optimality objective
The objective function in Equation (5) considers only the
EIG. This objective function can be modified to account
for sensor cost and to apply a nonuniform weighting to the
posterior covariance Γpost.
1) Sensor cost considerations: The cost of placing seafloor
sensors can vary based on a number of factors, including
depth, access rights, and ease of connectivity to the rest of
the network. Such variable cost factors can be incorporated
into the OED objective by using a weighted noise covariance
˜Γnoise = WcΓnoise. Here, Wc is a matrix that determines the
Algorithm 1 Sequential greedy algorithm for block D-optimal
sensor selection. This algorithm assumes isotropic noise, but
can be easily modified to handle extensions. K is the dense
data-space Hessian, C is the set of candidate sensors (corre-
sponding to block-rows and columns of K), and B is sensor
selection budget (i.e., number of sensors to be selected).
1: procedure SELECT SENSORS(K, C, B)
2: S ← ∅
3: LS ← [ ] ▷ Initialize empty global Cholesky factor
4: for k = 1 . . . B do
5: dmax, s∗ ← −∞, null
6: for s ∈ C \ S do
7: if k = 1 then
8: Ms ← Ks,s
9: else ▷ Triangular solve + Schur complement
10: Solve LS Ys = KS,s for Ys
11: Ms ← Ks,s − Y⊤
s Ys
12: LM,s ← Cholesky(Ms)
13: ds ← 2 · Sum(log (diag(LM,s))) ▷ Log-det.
14: if ds > dmax then ▷ Update best candidate
15: dmax, s∗, LM ∗ ← ds, s, LM,s
16: if k > 1 then
17: Ys∗ ← Ys
18: S ← S ∪ {s∗} ▷ Add new sensor to optimal set
19: if k = 1 then
20: LS ← LM ∗
21: else
22: LS ←
h LS 0
Y⊤
s∗ LM ∗
i
▷ Block update
23: return S
cost of placing each sensor. If the sensor cost is only dependent
on properties (e.g., location) of the individual sensor, Wc
is a diagonal matrix. However, a more complicated, cross-
correlated cost structure can also be used. By using the matrix
K created with the weighted noise covariance, the OED prob-
lem can incorporate sensor placement costs without modifying
the sensor selection algorithm. The scale of the weight matrix
Wc relative to FG∗ and Γnoise is a hyperparameter that can
be tuned on a problem-specific basis.
2) Nonuniform weighting of uncertainties: In practical ap-
plications, the posterior uncertainty field might not be uni-
formly important over the entire spatiotemporal parameter
field. For example, we may want to reduce parameter uncer-
tainties more in specific parts of the domain, and we may
not care at all about the parameter uncertainties in other
parts of the domain. Similarly, we may care more about
reducing parameter uncertainties in a specific time interval.
These considerations can easily be incorporated into the
framework described above by modifying the full K matrix
once before performing the optimal sensor selection. Recall
that K = Γnoise + FΓpriorF∗. We define the modified matrix
˜K := Γnoise + FWmΓpriorW∗
mF∗, where Wm is a diagonal
weighting matrix that applies the nonuniform weighting to the
spatiotemporal parameter field. Then, we can run the sensor
selection Algorithm 1 to determine the optimal sensors with
respect to this weighted measure of uncertainties.
H. Submodularity of the D-optimal objective
As mentioned previously, the full combinatorial optimiza-
tion problem in Equation (3) is NP-hard. While we use a
greedy algorithm to obtain an approximate solution, it is
important to understand the theoretical bounds associated with
this approximation. For this purpose, we first define the notion
of a submodular function.
Definition 1 (Submodularity): A set function f : 2V → R
is submodular if for all subsets X ⊆ Y ⊂ V and any element
e ∈ V \ Y , we have:
f (X ∪ {e}) − f (X) ≥ f (Y ∪ {e}) − f (Y ).
This property formalizes the concept of “diminishing returns.”
For a symmetric positive definite (SPD) matrix K, the
submodularity of the log-determinant of its principal sub-
matrices is a well-established result that can be shown via
information-theoretic methods relating the objective to Shan-
non entropy of a multivariate Gaussian, which is fundamen-
tally submodular [44]. The result can also be derived from
standard linear algebraic methods using the properties of Schur
complements [45].
Furthermore, foundational results for submodular maxi-
mization [46], [47] ascertain that the optimal sensor set
obtained from our greedy algorithm is at least (1−1/e) ≈ 63%
as good as the globally optimal sensor set.
While the submodularity of the D-optimal objective function
naturally suggests the use of the lazy greedy (or accelerated
greedy) algorithm to reduce the total number of candidate
evaluations (e.g. [48]), such approaches are structurally incom-
patible with the large-scale distributed architectures we target.
The lazy greedy algorithm relies on maintaining a dynamic
priority queue of marginal gains. The inherently sequential
nature of querying and updating a global priority queue
would introduce large synchronization bottlenecks, starving
the GPUs and negating the ideal parallel efficiency achieved
by the standard greedy algorithm. When the objective function
evaluation is extremely expensive, lazy greedy methods can be
useful; the design and parallel implementation of Algorithm 1
allow us to operate in the opposite regime. By leveraging the
scalability of our algorithm, we can rapidly iterate on sensor
designs with varying budget constraints.
IV. RESULTS
The multi-GPU version of Algorithm 1 was implemented
using PyTorch and mpi4py to enable performance portability
and ease of use. The dense matrix K is stored on disk in
double precision (float64), as it is used elsewhere in the
Bayesian inversion framework where stable inversion from
noisy data precludes the use of lower precision calculations.
However, all dense linear algebra computations within the
candidate evaluation loop are performed in single precision
(float32). Because the exact scalar values of the objective
function are utilized solely to determine the relative ordering
of candidate configurations during the greedy selection phase,
single precision provides sufficient accuracy while halving the
active memory footprint and providing significantly higher
GPU throughput. The single-precision computations were also
compared to double-precision versions, and the obtained sen-
sor selections agree exactly for a given sensor budget.
To validate the theoretical algorithmic complexity and
systems-level optimizations detailed in the previous sections,
we developed a suite of application-oriented computational
benchmarks. These benchmarks evaluate both the single-GPU
performance of the proposed block Schur complement update
method and the distributed-memory parallel scalability of the
full pipelined sensor selection framework. The benchmarks are
designed to evaluate the performance of the OED implemen-
tation at the full scale of the tsunami digital twin application
as well as to determine its scalability to even larger problem
sizes.
A. Single-GPU performance results
To quantify the single-GPU performance of the algorith-
mic design and implementation, a computational study was
conducted across three GPU architectures: an NVIDIA A100
(80 GB), an AMD MI250X (64 GB), and an NVIDIA GH200
Superchip (96 GB). The study considers two implementations
of the objective function evaluation step:
1) Naive formulation:1 Computes the objective by refac-
torizing the full augmented test matrix from scratch for
each candidate.
2) Schur formulation: The proposed method, leveraging
the block Schur complement update to avoid redundant
factorizations.
Both implementations employ strict in-place memory opera-
tions to minimize the GPU memory footprints, which increases
the possible budget size B. Intermediate tensors are pre-
allocated outside the inner loop. The default PyTorch backend
is used for the linear algebra operations, which uses an internal
heuristic to determine whether cuSOLVER/hipSOLVER or
MAGMA [49] is called at runtime.
For this benchmark, the number of timesteps (i.e., the
observations per sensor location) is fixed to Nt = 420, selected
based on a realistic sampling frequency of 1 Hz over a 7-
minute inversion time window [50]. The computational cost
per sensor selection iteration also depends on the current iter-
ate k, which defines the number of already-selected sensors,
and the total budget B. In the benchmark, k is swept from
10 sensors to a maximum budget of 600 in increments of
10. For each value of k, we measure the peak GPU memory
allocated and the average compute time per candidate over 10
independent runs. If an algorithm variant exceeds the device’s
specific memory limit for a given k, it is marked as an out-of-
memory (OOM) failure and excluded from subsequent, larger
budget evaluations. CUDA/HIP events are used to measure the
1“Naive” here refers only to the method of fully refactorizing the test matrix
for each candidate sensor. The OED algorithm itself is still based on the
efficient data-space formulation; without this formulation, the OED problem
would be entirely intractable (see Section I).
GPU execution times, averaging over 10 runs after a warm-
up period (we note that the observed variance between the
independent runs is negligible).
The benchmark results are shown in Figure 2. The plots
illustrate that the Schur complement algorithm (plot b) is
several orders of magnitude faster than the naive algorithm
(plot a). Both the naive and Schur implementations follow the
expected asymptotic behaviors estimated in Section III-E. Both
algorithms have a memory complexity scaling with Ok2/span>,
but the Schur algorithm’s overall memory footprint remains
much smaller. The relatively larger storage requirement of
the naive algorithm results in a decreased maximum budget
size. Using the Schur formulation, the maximum budget is
300 on the 64 GB MI250X (single GCD), 340 on the 80 GB
A100, and 370 on the 96 GB GH200. We use the more
memory-efficient and higher-performing Schur formulation for
testing the scalability of our OED implementation on the target
machines: Perlmutter and Frontier.
B. Parallel scaling methodology and I/O optimization
We assess the distributed-memory performance of our OED
algorithm with scaling studies across two distinct supercom-
puting facilities: NERSC’s Perlmutter and OLCF’s Frontier.
Perlmutter’s GPU partition features an AMD EPYC 7763 64-
core CPU and 4 NVIDIA A100 GPUs per node, backed by a
35 PB all-NVMe Lustre scratch file system. Frontier, the first
exascale system, features an AMD EPYC 7713 64-core CPU
and 4 AMD MI250X GPUs (8 Graphics Compute Dies, or
GCDs) per node, backed by the Orion file system based on
Lustre and HPE ClusterStor. In all tests, one MPI rank is used
per GPU device/GCD.
In our strong and weak parallel scalability studies, the
number of timesteps Nt is kept fixed at 420. The global
problem size for strong scaling uses 8,192 candidate sensors,
and the local problem size for weak scaling uses 256 candidate
sensors per GPU. The scalability tests measure the algorithm’s
performance at the k = 175-th iterate of the sensor selection.2
Scaling studies were conducted with up to 512 GPUs on
Perlmutter and Frontier (up to 1,024 GCDs).
With these scaling configurations, the largest problem sizes
for weak scalability would require storing candidate matrices
that can exceed practical limitations of filesystem access on
shared computing facilities. However, for the purpose of test-
ing the scalability of the OED algorithm, we can instead use a
smaller candidate matrix, based on just 600 candidate sensors,
and simulate larger numbers of candidates by using a modulo
indexing system: candidate indices are mapped modulo 600
to the HDF5 dataset. To prevent unwanted filesystem caching
effects, the global list of candidates is randomized before being
distributed to the individual GPUs. The full 252, 000×252, 000
2Computing scaling results over the full OED algorithm would require
long compute times. While the sensor selection times vary for each iterate,
and generally grow with k (see Section III-E), we note that similar weak and
strong scaling results were observed for other iterates, both k < 175 and
k > 175.
0 50 100 150 200 250 300 350 400
Selected Sensors (k)
0
100
200
300
400
500
600
700
Time per Iteration (s)
NVIDIA A100
AMD MI250X
NVIDIA GH200
O(k3)(a) Naive Formulation (O(k3))0 50 100 150 200 250 300 350 400
Selected Sensors (k)
0.0
0.2
0.4
0.6
0.8
Time per Iteration (s)
NVIDIA A100
AMD MI250X
NVIDIA GH200
O(k2) (b) Schur Formulation (O(k2))
Fig. 2: Single-GPU execution times per candidate evaluated across the three accelerator architectures. (a) The naive formulation
exhibits O(k3) polynomial scaling. (b) The Schur complement formulations reduce the complexity to O(k2), significantly
reducing the compute time for each candidate evaluation and enabling practical scaling to massive candidate pools. Dashed
gray lines represent theoretical asymptotic behavior. The maximum number of selected sensors for each GPU architecture is
determined by its memory limit.
candidate matrix K is stored in double precision as a 464 GB
chunked HDF5 2D dataset.
To maximize I/O throughput, cross-facility file stripe sizes
were set according to system guidelines. On Perlmutter, the
HDF5 file was explicitly restriped across 128 Lustre OSTs
with 2 MB extents. On Frontier’s Orion file system, manual
striping was intentionally omitted, because the dataset fell
below the 512 GB manual-striping threshold. Thus, the default
Progressive File Layout (PFL) was utilized, allowing the
OLCF system wrapper to automatically manage optimal data
distribution. Additionally, the internal HDF5 chunk cache and
file locking mechanisms were disabled (rdcc_nbytes=0,
and export HDF5_USE_FILE_LOCKING=FALSE). This
further increased performance by reducing CPU memory
copies and unwanted blocks or synchronizations.
Execution timers were recorded locally on all MPI ranks
using MPI_Wtime. The reported runtimes correspond to the
maximum total wall time for all candidate evaluations across
all ranks. Each scaling test was performed several times at
different periods throughout the day to account for variations
in filesystem performance; the observed variance between the
independent runs was negligible. The communication times of
the MPI_Allreduce (for determining the global maximizer
or best candidate) were also measured; these are negligible
compared to the overall computation and I/O times.
C. Multi-GPU scalability results
Strong scaling reflects the main operational goal of the
framework: minimizing the time-to-solution for a fixed candi-
date pool. Solving the OED problem is a “one-time” offline
computation, but the particular OED formulation in practice
depends on external factors such as sensor deployment cost
models, expectations about potential earthquake scenarios, and
other prior knowledge that may be incorporated in the OED
problem formulation (see Section III-G2). Decreasing time-
to-solution will thus enable rapid OED computations for dif-
ferent configurations of these external parameters. Decreasing
the time for objective function evaluations may also enable
alternative optimization algorithms that require more candidate
evaluations than our greedy selection approach does.
To evaluate the framework’s ability to maintain parallel
efficiency as the problem size grows proportionally with the
hardware, a weak scaling study was also conducted. The
workload was fixed at 256 candidate evaluations per MPI rank,
scaling the total number of candidate evaluations up to 131,072
on Perlmutter and 262,144 on Frontier.
Figure 3 shows the strong and weak scalability results.
We observe near-ideal weak and strong scaling over a 128×
processor increase on both Perlmutter and Frontier. While
the computation phase of the algorithm is embarrassingly
parallel, it is the pipelined execution scheme masking I/O
behind compute that allows the multi-GPU implementation
to reach this high parallel efficiency. Initial implementations
involving sequential I/O-compute phases did not exhibit this
level of scalability. Note that while the x-axis on Figure 3
reports number of GPUs, each GPU on Frontier comprises 2
GCDs; the effective number of devices on Frontier is doubled.
D. Optimal sensor placement for Cascadia digital twin
We applied our optimal sensor selection algorithm to a digi-
tal twin for tsunami early warning in the Cascadia Subduction
Zone (CSZ), using the framework proposed in the Gordon Bell
4 8 16 32 64 128 256 512
Number of GPUs
2
4
8
16
32
64
128
256
512
Wall Time (s)
100%
100%
98%
100%
100%
99%
99%
97%
100%
101%
101%
100%
100%
98%
96%
91%
Perlmutter
Frontier
Observed
Ideal(a) Strong Scaling Performance4 8 16 32 64 128 256 512
Number of GPUs
0
10
20
30
40
50
60
Wall Time (s)
100% 101% 101% 101% 101% 101% 101% 99%
100% 100% 100% 99% 99% 99% 99% 99%
Perlmutter
Frontier
Observed
Ideal (b) Weak Scaling Performance
Fig. 3: Parallel (a) strong and (b) weak scaling performance of the fully-pipelined OED algorithm on NERSC’s Perlmutter
and OLCF’s Frontier supercomputers. Observed wall times are plotted alongside ideal (linear) scaling baselines. The scaling
efficiency percentage relative to the initial single-node baseline is annotated beside each marker, demonstrating robust parallel
scalability across a 128× increase in GPUs. Note that each GPU on Frontier consists of 2 GCDs.
Prize-winning work [7]. In that work, the authors presented
a digital twin that can infer the earthquake-induced seafloor
motion from seafloor pressure observations in real time, and
use the inferred field to forecast tsunami wave heights. This
was demonstrated for a realistic Cascadia earthquake rupture
scenario [51] using synthetic data from 600 hypothesized
seafloor sensor locations across the CSZ.5.3 5.4 5.5 5.6 5.7
Objective Function Value ×105
0.0
0.5
1.0
1.5
2.0
2.5
Probability Density
×10 4
Random Configurations
Optimal Configuration
Fig. 4: Histogram of the objective-function values for 100
random configurations of 175 sensors each, compared with
the greedy-optimal configuration. The optimal configuration
performs significantly better than the random ones.
This hypothetical configuration of 600 sensors, depicted in
Figure 1, was approximately uniformly distributed over the
subduction zone. Given budget and logistical constraints for
offshore sensor deployment, it is unlikely that this type of
configuration could be deployed in practice [11]. More likely,
a large-scale sensor network in Cascadia could be of the size of
Japan’s S-net, which consists of 150 seafloor stations. Thus,
using the 600 sensors from [7] as the candidate set C, we
performed the optimal sensor selection (Algorithm 1) for a
budget of B = 175 sensors.
The 600 adjoint PDE solutions of the acoustic–gravity wave
equations that are needed to form the shift-invariant p2o map
F were computed in approximately 500 hours on 512 A100
GPUs, using a finite element implementation of the PDE
model in MFEM [52], [53]. After that, forming G∗ and subse-
quently K took 3 hours on 512 A100 GPUs. Then, the multi-
GPU version of Algorithm 1 was run on the candidate matrix
K using 16 A100 GPUs, taking approximately 1.5 hours. All
of these computations were performed on Perlmutter.
As shown in Section III-H, the result of the greedy algo-
rithm will be at least 63% as good as the global optimizer
to the combinatorial optimization problem in Equation (3).
Figure 4 compares the values of the objective function ˜Φ
(assuming isotropic noise—see Equation (5)) for 100 random
configurations of 175 sensors to that of the greedy-optimal
configuration. The greedy-optimal configuration outperforms
the random configurations by a significant margin.
Figure 5 shows the results of Algorithm 1 applied to the
Cascadia digital twin with a budget of 175 sensors for the
K matrix of 600 candidate locations. Specifically, the plots
of Figure 5 illustrate the reduction in the (time-integrated)
posterior uncertainty field, depicted as pointwise standard
deviations of the inferred seafloor displacement, as sensors
are added iteratively. In other words, the plots visualize the
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
mathematically rigorous, uncertainty-aware optimization.
ACKNOWLEDGMENTS
This research was supported by DARPA COMPASS grant
HR0011-25-3-0242, DOD MURI grant FA9550-24-1-0327,
and DOE ASCR grant DE-SC0023171.
This research used resources from the National En-
ergy Research Scientific Computing Center (NERSC) under
allocations ALCC-ERCAP0030671, ScienceAtScale DDR-
ERCAP0034808 and NESAP DDR-ERCAP0038013. This re-
search used resources of the Oak Ridge Leadership Computing
Facility at the Oak Ridge National Laboratory, which is
supported by the Office of Science of the U.S. Department
of Energy under Contract No. DE-AC05-00OR22725. The
authors acknowledge the Texas Advanced Computing Center
(TACC) at The University of Texas at Austin for providing
computational resources that have contributed to the research
results reported within this paper.
