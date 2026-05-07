# Comparing Classical and Quantum Deep Learning Techniques for Anomaly Detection of Short-Duration Gamma-Ray Signals — excerpt

## Ingest record

- SOURCE_TITLE: `Comparing Classical and Quantum Deep Learning Techniques for Anomaly Detection of Short-Duration Gamma-Ray Signals`
- DOI: `10.1016/j.ascom.2026.101090`
- CLASSIFICATION: `staged`
- EPISTEMIC_LEVEL: `claim`
- AUTHORITY: `operator-provided paper excerpt`
- PROJECT: `quantum`
- DOMAIN: `quantum_ml_astrophysics`
- NOTE: `Preserved as staged excerpt. Includes methods, architecture descriptions, dataset-generation details, and references to formulas/figures whose full mathematical rendering is incomplete in pasted text.`

## Math/formula handling note

The pasted excerpt clearly references equations and figure-bound formulas, but the actual formula rendering is incomplete in plain text at several points (for example, missing visible expressions around normalization, qubit-state notation, and Li & Ma significance equations). So the excerpt preserves:
- the surrounding explanation
- where formulas are used
- what they are intended to compute

But not every symbolic formula is fully reconstructable from the pasted text alone.

## Operator-provided excerpt

### Quantum / deep learning context and abstract-level framing

This paper compares classical and quantum autoencoders for anomaly detection of short-duration gamma-ray burst (GRB) signals in a controlled astrophysical setting. The work emphasizes resource-constrained scenarios with limited data and trainable parameters, and reports that quantum autoencoders can be competitive under lightweight-model conditions even when classical autoencoders reconstruct more accurately in absolute terms.

### Methods and algorithms for anomaly detection

Deep learning and anomaly detection are introduced through classical autoencoders trained on background-only data. The reconstruction-error paradigm is used to flag anomalies, with GRB events treated as out-of-distribution inputs that should reconstruct poorly relative to normal background patterns.

### Quantum computing / quantum autoencoder section

The excerpt explains:
- qubits as the quantum analogue of classical bits
- superposition and entanglement as core principles
- quantum circuits and gates as the computational mechanism
- NISQ-era hardware limitations
- hybrid quantum-classical training via variational quantum algorithms and parameterized quantum circuits
- amplitude encoding as the chosen data-embedding strategy
- the quantum autoencoder objective of compressing and reconstructing quantum states

The excerpt also notes an improved feature-vector-encoding variant and cites Romero et al. (2017) as the original QAE reference.

### Dataset and simulation setup

The study uses simulated light curves for the COSI mission context, with separate background-only and background-plus-GRB datasets. Background-only data are generated from fitted background count distributions, while GRB light curves are created from a single GRB template and augmented stochastically.

The excerpt records several operational details:
- COSI BGO background simulations
- Gaussian fit to background counts
- train/validation/test splits
- Min–Max normalization
- 32-bin and 128-bin cases
- limited sample-size experiments (100, 1000, 5000)
- GRB injection at a fixed offset in the light curve
- Li & Ma significance used to quantify GRB significance

### Cryptography / infrastructure / scalability framing from earlier excerpt continuity

This paper section remains relevant to the broader quantum-memory house because it intersects with:
- hybrid quantum-classical computing
- software tooling and parameterized circuits
- NISQ constraints
- anomaly detection with quantum machine learning
- practical, domain-bound use rather than universal quantum claims

### Formula visibility limitation

The excerpt visibly references formulas for:
- normalization / Min–Max scaling
- qubit-state notation and amplitude encoding
- Li & Ma significance

However, the exact symbolic equations are not fully preserved in the pasted text. The location and role of the formulas are preserved, but not all mathematical symbols survive in readable form.
