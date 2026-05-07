# GRB quantum/classical autoencoder paper — results and conclusions continuation

## Ingest record

- SOURCE_TITLE: `Comparing Classical and Quantum Deep Learning Techniques for Anomaly Detection of Short-Duration Gamma-Ray Signals`
- DOI: `10.1016/j.ascom.2026.101090`
- SECTION_SCOPE: `Results, comparison, and conclusion sections plus appendix continuity`
- CLASSIFICATION: `staged`
- EPISTEMIC_LEVEL: `claim`
- AUTHORITY: `operator-provided paper excerpt`
- PROJECT: `quantum`
- DOMAIN: `quantum_ml_astrophysics_results`
- NOTE: `Preserved as staged results/conclusions material. Includes comparative performance claims, parameter counts, timing/memory observations, and architectural interpretations. Some table cells remain visually incomplete in plaintext.`

## Handling note

This continuation is much stronger on:
- empirical comparison
- resource-constraint claims
- trainable-parameter counts
- performance metrics (MAPE, precision, recall, F1)
- interpretation of classical vs quantum tradeoffs

However, some table entries and a few parameter-count values are still visually incomplete in the pasted text, so exact numeric extraction is only partial.

## Key preserved claims

### Classical baseline
- Classical autoencoders achieve superior reconstruction accuracy when allowed higher capacity and larger datasets.
- Classical performance degrades strongly under low-data and low-parameter conditions.
- For 5000 samples, the best classical model reaches very low test MAPE (reported as 0.82%).
- Smaller classical models (e.g. 705 and 1081 parameters) degrade substantially under constrained conditions.

### Quantum results
- Quantum models were tested mainly on 32-bin light curves, where they performed best.
- Real Amplitudes and Efficient SU2 were among the key ansaetze explored.
- Quantum models show relatively stable performance across 100, 1000, and 5000 sample regimes.
- Quantum models use dramatically fewer trainable parameters than classical baselines (e.g. 10 parameters for Real Amplitudes, 20 for Efficient SU2 in 5-qubit / 1-layer settings).
- Reported test-set MAPE remains around ~6.7% to ~7.1% across the examined quantum settings.

### Comparative interpretation
- The paper argues that quantum autoencoders can outperform small classical autoencoders in resource-constrained scenarios.
- The paper also states that high-capacity classical autoencoders still outperform the quantum approach at full capacity.
- The claimed quantum advantage is therefore conditional, not general: strongest in low-data / low-parameter settings.
- The paper explicitly notes current limitations due to simulator/runtime cost, encoding overhead, and hardware constraints.

### Runtime / resource observations
- For a 5000-sample case, a large classical model reportedly converged in 47 seconds.
- A quantum Real Amplitudes configuration reportedly required 27 minutes and 52 seconds.
- Reported memory increment was much smaller for the quantum architecture than for the classical one, attributed to fewer trainable parameters.
- The paper identifies data encoding as a major bottleneck for quantum models.

### Interpretation caveat
- The excerpt contains strong comparative claims that are useful and interesting, but they remain paper-specific empirical claims until independently benchmarked or corroborated.
- These are excellent staged claims for later extraction, especially around low-parameter efficiency, but should not be silently promoted to general canon without further validation.
