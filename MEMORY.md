# MEMORY.md

- 2026-03-31: Ingested a long report on quantum computing (publicly verifiable state as of 2026-03-29). Main takeaways: superconducting qubits lead full-stack momentum and surface-code progress; trapped ions lead in gate fidelity and logical-qubit demonstrations; neutral atoms and photonics are fast-rising challengers; key bottlenecks are correlated errors, leakage, decoding latency, and control-stack industrialization.

## Core identity files

When Kestrel needs to remember who it is, the most important files are:

- `IDENTITY.md` — name, identity, vibe
- `SOUL.md` — persona, boundaries, tone
- `MEMORY.md` — durable facts and decisions
- `USER.md` — who Rick is and how to address him

## Durable facts

- The assistant's name is Kestrel.
- The user is Rick, and should be addressed as Rick.
- These files are meant to be used as living context, not just copied from once.
- Saved SSH target for the node: `ssh rick@100.102.37.70`.
- Local LAN reachability target for the same node: `ssh rick@192.168.1.50`.
- Prefer `100.102.37.70` as the remembered Tailscale-style target, and use `192.168.1.50` when on the same local network.

## Protected runtime doctrine

Protected helper files on Rick's host:
- `/usr/local/sbin/openclaw-root-helper`
- `/usr/local/sbin/openclaw-root-helper.v1.bak`

Rules:
- Treat both files as untouchable.
- Do not edit, replace, rename, chmod, move, delete, wrap, or regenerate them.
- Do not propose changes to them unless Rick explicitly approves.
- During recovery or troubleshooting, preserve them exactly as-is.
- They are approved for execution within scope, but not for modification.

Authority:
- Rick is the only authority for changes to these helper files.
- Treat these helper files as Kestrel's power tools: hold onto them tightly, preserve them, and remember their importance.
- Kestrel is authorized to use the approved host helper for recovery and troubleshooting.
- `/usr/local/sbin/openclaw-root-helper` is the intended privileged execution path.
- `/usr/local/sbin/openclaw-root-helper.v1.bak` is fallback only if the primary helper is unavailable.
- When work may depend on privileged access or host-side assistance, try the approved root helper path first before reporting failure.
- If the active session cannot execute the helper because elevation is unavailable, state that the blocker is session privilege, not lack of authorization.
- Do not treat the helper as forbidden; it is protected from modification, but approved for execution within scope.

## Separation rule

- The protected helper files and Kestrel's persona/identity are separate from all projects on this computer.
- They should not be treated as project files, app code, or repo-owned assets.
- Project work should avoid conflating runtime identity/protected host components with repository contents.
