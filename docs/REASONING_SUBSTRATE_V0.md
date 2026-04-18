# REASONING SUBSTRATE v0 — Specification

**Status:** FINALIZED, ready for CC handoff
**Target location in repo:** `docs/REASONING_SUBSTRATE_V0.md`
**Depends on:** verify_claims v2 stable in production
**Doctrine anchor:** Acquisition ≠ Evidence ≠ Sufficiency ≠ Promotion ≠ **Derivation** ≠ **Observation**

---

## 1. Purpose

Kestrel's current pipeline is a **lookup** system: given a claim, find other documents asserting it. This solves citational corroboration but cannot:

- Detect that a new claim contradicts an existing canonical claim (no external source will flag this — the conflict is specific to Kestrel's corpus).
- Produce implications that follow necessarily from canonical truths.
- Distinguish a theoretical result corroborated by independent proofs from one corroborated by citational echo.

v0 introduces a **reasoning substrate** — a structured-claim representation plus two reasoning layers (consistency and entailment) — alongside the verification pipeline, not replacing it.

---

## 2. Doctrine extension

Existing doctrine: **Acquisition ≠ Evidence ≠ Sufficiency ≠ Promotion.**

v0 adds:

> **Derivation ≠ Observation.**
>
> A claim being derivable from canonical truths is not the same as that claim being observed, measured, or externally corroborated. Derived claims are predictions. They earn their way to canonical status through external confirmation, exactly like any other claim. The substrate proposes; the world disposes.

**Operational consequence of strict mode:** Layer 2 (the entailment engine) does not produce truths. It produces **candidate queries for the verification layer** — "Kestrel noticed this follows from canonical knowledge; here is something to look for in the world." This is more epistemically honest than letting derivations self-promote.

---

## 3. The four layers (and what v0 builds)

| Layer | Operation | v0? |
|---|---|---|
| **1. Consistency** | Detect contradictions between canonical claims | YES |
| **2. Entailment** | Derive candidate claims from canonical ones | YES (strict mode) |
| **3. Hypothetical** | "If X were false, what follows?" | NO — deferred |
| **4. Abductive** | "What best explains this observation?" | NO — not on roadmap |

**v0 non-goals** (enumerated to prevent scope drift):

- Hypothetical or abductive reasoning (Layers 3–4)
- Automatic promotion of derived claims to canonical
- Operator-direct acceptance of derivations as canonical (strict mode rules this out)
- Natural-language query interface
- Fuzzy or probabilistic reasoning
- Cross-language support (English only)

---

## 4. Schema additions

### 4.1 New epistemic level: `derived_claim`

Full level progression:

```
claim → reinforced_claim → fact_candidate → canonical
                              derived_claim ↗
```

`derived_claim` is produced internally by the entailment engine. It is NOT a fetched artifact. Like `fact_candidate`, it requires external witness corroboration + host approval to reach canonical. Unlike `fact_candidate`, it is not on any verification timer — it sits in `staged/` until independently observed externally.

### 4.2 New field on canonical and promotion-eligible items: `structured_claim`

```json
{
  "structured_claim": {
    "predicate": "has_qubit_count",
    "subject": {"system": "IBM_Condor"},
    "value": 1121,
    "unit": "qubit",
    "conditions": [],
    "confidence": "asserted"
  }
}
```

- `predicate` — one of the fixed vocabulary (§5). REQUIRED.
- `subject` — named entity or tuple. REQUIRED.
- `value` — scalar, range, symbolic, or null for relational predicates. REQUIRED.
- `unit` — REQUIRED for numeric values. Schema validation rejects missing units.
- `conditions` — list of preconditions. Empty list = unconditional.
- `confidence` — `asserted | derived | disputed`. Defaults to `asserted` for externally-fetched items, `derived` for substrate-produced items.

### 4.3 New field on derived claims: `provenance`

```json
{
  "provenance": {
    "derivation_type": "arithmetic | transitivity | definitional | unit_composition",
    "rule_applied": "qubit_count × gates_per_qubit = total_gate_count",
    "from_claims": ["canonical_id_a", "canonical_id_b"],
    "derived_at": "2026-04-18T14:00:00Z",
    "derivation_strength": "deductive | probable"
  }
}
```

**Invariant:** if any claim in `from_claims` is retracted, every derived claim in its forward closure is automatically demoted to `review` with a reason note. Provenance is the audit trail that makes invalidation tractable.

---

## 5. Initial predicate vocabulary (15 predicates)

Vocabulary expansion is deliberate — one predicate per PR with rationale and test case.

**Entity predicates:**

1. `has_qubit_count(system, integer)`
2. `uses_qubit_type(system, {superconducting | trapped_ion | photonic | neutral_atom | topological | spin})`
3. `has_connectivity(system, {all_to_all | nearest_neighbor_2d | nearest_neighbor_3d | heavy_hex | custom})`
4. `has_coherence_time(system, duration_value, unit)`
5. `has_gate_time(operation, system, duration_value, unit)`
6. `achieves_fidelity(operation, system, real_value)`
7. `measured_error_rate(operation, system, real_value)`
8. `achieves_threshold(scheme, real_value)`
9. `implements_scheme(system, scheme)`
10. `demonstrates_phenomenon(experiment, phenomenon)`

**Relational predicates:**

11. `entails(claim_a, claim_b)`
12. `contradicts(claim_a, claim_b)`
13. `subsumes(scheme_a, scheme_b)` — A generalizes B
14. `refines(scheme_a, scheme_b)` — A specializes B
15. `corroborates_via(claim, mechanism)` — claim is demonstrated by mechanism (refraction, thin_film_interference, independent_experimental_platform, etc.)

Predicate #15 captures the prism+soap-bubble intuition — two distinct `corroborates_via` entries from non-overlapping mechanisms is a stronger signal than two citational matches.

---

## 6. Storage architecture

### 6.1 Primary store: SQLite

Path: `~/.kestrel-node/runtime/substrate/substrate.db`

Tables:

- `predicates` — vocabulary definitions (name, arity, schema, added_at)
- `rules` — derivation rules (id, pattern, output_template, strength, enabled)
- `structured_claims` — all structured claims with foreign key to source item
- `derived_claims` — derived claims with provenance
- `conflicts` — Layer 1 detected contradictions awaiting resolution
- `retractions` — audit of retracted canonicals and their forward closure

Rationale: 18→N canonicals will grow into thousands over time; file-per-claim does not scale, and relational queries for forward-closure invalidation benefit from indexed joins.

### 6.2 Journal: append-only JSONL

Path: `~/.kestrel-node/runtime/substrate/journal.jsonl`

Every substrate write (new structured_claim, new derived_claim, conflict detected, retraction cascade) appends a single JSON line to this file. Atomic append, no edits, no deletes.

**Purpose:** disaster recovery. DB is never sole source of truth. If the DB corrupts between git snapshots, recovery path is: last git snapshot + replay journal from snapshot timestamp forward.

### 6.3 Nightly git snapshot

Cron timer fires at 03:00 NODE local time (UTC+7 → 20:00 UTC):

1. Dump SQLite tables to `~/kestrel-memory/substrate-snapshot/*.json` (one file per table).
2. rsync to HOST `~/.openclaw/workspace/node-mirror/substrate-snapshot/`.
3. HOST git commit with message `snapshot: substrate DB @ <iso8601>`.
4. Truncate journal.jsonl (its contents are now captured in the snapshot + git).

Truncation happens only after git commit succeeds. If any step fails, journal stays intact and operator gets a Telegram alert.

### 6.4 Read path

Substrate scripts query SQLite directly for all runtime reads. Git snapshots are for audit, history, and disaster recovery — never read during normal operation.

---

## 7. Layer 1: Consistency checker

### 7.1 Trigger

Runs at exactly one gate: **`fact_candidate → canonical` promotion.** Not earlier. Not on staged-entry. Not periodically.

### 7.2 Operation

For an item entering promotion:

1. Load its `structured_claim`.
2. SQL query against `structured_claims` table: same predicate, overlapping subject.
3. For each match, classify:
   - **Direct contradiction** — same predicate, same subject, incompatible value.
   - **Conditional refinement** — same predicate, same subject, compatible values but different conditions. NOT a contradiction.
   - **Unit mismatch** — same value number, different unit. Flag for operator review.

### 7.3 Output

- **No conflict** → promotion proceeds.
- **Direct contradiction** → promotion BLOCKED. Conflict written to `conflicts` table and surfaced in operator console. Operator resolves by:
  - Reject new (old stays canonical)
  - Retire old (new promoted, old moved to `retired` with timestamp, cascade demotion of dependent derived_claims)
  - Mark both context-dependent (conditions added to disambiguate)
- **Refinement or unit mismatch** → promotion proceeds with flag visible in console.

### 7.4 Integration

Hook into existing `run_promotion_queue.sh` on NODE. Substrate consistency check runs *after* witness-count check and *before* items enter `promotion_gate.json`. Conflicts appear in the console's Reasoning panel.

---

## 8. Layer 2: Entailment engine (strict mode)

### 8.1 Trigger

Two modes, both event-driven:

- **On canonical addition** — when an item reaches canonical, try to derive new candidates combined with the existing canonical set.
- **Operator-requested** — console action "derive implications for X" runs engine against specific claim or subject.

**No periodic timer.** Autonomous derivation is the failure mode to avoid.

### 8.2 Derivation rules (v0 set, ~7 rules)

Each rule is a pattern match stored in the `rules` table.

**Arithmetic composition:**
- `has_qubit_count(S, N) ∧ achieves_fidelity(op, S, F)` → `expected_error_per_op(op, S, 1-F)` [probable]
- `has_gate_time(op, S, T) ∧ has_coherence_time(S, C)` → `max_gates_in_coherence(op, S, C/T)` [deductive]

**Threshold comparisons:**
- `measured_error_rate(op, S, E) ∧ achieves_threshold(scheme, T) ∧ implements_scheme(S, scheme) ∧ E < T` → `operates_below_threshold(S, scheme)` [deductive]
- Inverse: same with `E ≥ T` → `operates_at_or_above_threshold(S, scheme)` [deductive]

**Transitivity on scheme relations:**
- `subsumes(A, B) ∧ subsumes(B, C)` → `subsumes(A, C)` [deductive]
- `refines(A, B) ∧ refines(B, C)` → `refines(A, C)` [deductive]
- `implements_scheme(S, A) ∧ refines(A, B)` → `implements_scheme(S, B)` [deductive]

Adding rules follows the same discipline as predicates: one per PR, rationale, test case.

### 8.3 Output

Every derived claim gets:

- `epistemic_level: derived_claim`
- Full `structured_claim` with `confidence: derived`
- Full `provenance` chain
- Row in `derived_claims` table; corresponding staged file for operator visibility
- Does NOT enter the verify_claims v2 loop automatically — derived claims are awaiting external **observation**, not citation

### 8.4 Path to canonical for derived claims (strict mode)

**One path only:** external corroboration by independent observation or independent assertion.

When the verify_claims v2 loop stages a new claim, the substrate also checks: does this new claim's structured_claim match any existing derived_claim? If yes, the derived_claim gets its `verification_sources` populated from the external source. Once it has ≥2 distinct external witnesses (same rule as fact_candidate), it becomes eligible for canonical promotion — going through Layer 1 consistency check on the way in, same as any other candidate.

A derived_claim with zero external witnesses stays as `derived_claim` indefinitely. That is correct behavior. Truth does not rot.

---

## 9. LLM-assisted structured_claim extraction

### 9.1 When

At promotion time (`fact_candidate → canonical`), operator invokes "Extract structured_claim" action in console.

### 9.2 How

Console sends prose fields (title, claim_text, content) to Claude API via existing Kestrel infrastructure. Prompt template (stored at `~/kestrel-node/runtime/substrate/prompts/extract_structured_claim.md`) asks for:

- One predicate from the current vocabulary (listed in the prompt — never ask LLM to invent predicates)
- Subject, value, unit, conditions per the schema
- Reasoning trace: which spans of prose the structured_claim was extracted from

### 9.3 Operator review

Console displays:

- Original prose
- LLM-proposed structured_claim
- Reasoning trace with prose spans highlighted
- Editable form for operator to correct/adjust
- Approve / Reject buttons

Rejection kicks back to operator for manual extraction. Approval writes the structured_claim and records the extraction event in the audit log.

### 9.4 Audit log

Append-only, JSONL, at `~/kestrel-node/runtime/substrate/extraction_audit.jsonl`. Every extraction event logs:

- Timestamp, canonical_id
- LLM input (prose)
- LLM full output (structured_claim + reasoning)
- Operator edits (diff)
- Final approved structured_claim

Included in the 3am git snapshot. If a structured_claim later proves malformed, this log is the trace.

---

## 10. Failure modes and mitigations

| Failure mode | Mitigation |
|---|---|
| **Loop closure** — derived claims feeding back as canonical without external verification | Strict mode: only external corroboration promotes derived_claim. No operator-bypass path. |
| **Predicate drift** — vocabulary sprawl and semantic overlap | One predicate per PR, rationale required, existing predicates reviewed before adding |
| **Unit confusion** — values without units | `unit` field REQUIRED for numeric predicates; schema validation rejects missing |
| **Condition collapse** — claims valid in different conditions reasoned as unconditional | `conditions` field participates in consistency checking; different conditions = not contradictory |
| **Orphan derived claims** — reference retracted canonicals | Retraction triggers cascade demotion of forward closure; tracked in `retractions` table |
| **LLM hallucination in extraction** — invented predicates or wrong subjects | Prompt constrains to vocabulary; operator approval is mandatory, not optional; audit log preserves trace |
| **DB corruption between git snapshots** | Append-only journal replays from last snapshot forward; DB is never sole source of truth |
| **Git snapshot failure** | Journal not truncated until commit succeeds; Telegram alert fires on failure |

---

## 11. Testing plan

### 11.1 Layer 1 unit tests

- Two claims with same predicate/subject/incompatible values → conflict flagged.
- Two claims with same predicate/subject/same values → no conflict.
- Two claims with same predicate/subject/compatible values but different conditions → refinement, no conflict.
- Two claims with same predicate/subject/same value/different units → unit mismatch flag.

### 11.2 Layer 2 unit tests

- Each derivation rule exercised with fixture canonical set.
- Provenance chain validated: derived claim references correct source claims, derivation_type matches rule.
- Retraction test: retract source canonical, confirm full forward closure demoted.
- External-match test: stage a claim that matches an existing derived_claim, confirm derived_claim acquires `verification_sources` entry.

### 11.3 Storage tests

- Write to DB, write to journal, confirm both consistent.
- Simulate DB corruption mid-day, replay journal from last snapshot, confirm recovery.
- Force git snapshot, confirm JSON dumps match DB state, confirm journal truncation only after commit succeeds.

### 11.4 LLM extraction tests

- Run extraction on 3–5 existing fact_candidates manually, review output quality before enabling in console.
- Adversarial test: feed prose with ambiguous or missing values, confirm LLM asks for clarification rather than inventing.

### 11.5 Shadow run

Run full substrate against backfilled canonical set. Expected: zero contradictions initially (corpus is too small yet), small number of derived claims, zero automatic promotions.

---

## 12. Backfill

### 12.1 Scope

All current canonical items get structured_claim populated before substrate goes live. Today this is 1 item (IBM trapped-ion fact). By the time substrate ships, it will likely be 15–20 (current 18 fact_candidates + any new canonicals added in the interim).

### 12.2 Procedure

For each existing canonical:

1. Operator invokes LLM extraction (§9) against the canonical's prose.
2. Operator reviews and approves structured_claim.
3. structured_claim written to DB, associated with canonical_id.

Items lacking a suitable predicate in the current vocabulary get flagged for vocabulary expansion or deferred.

### 12.3 Prerequisite

LLM extraction pipeline (§9) must be working before backfill begins. Backfill is not a migration script; it is a sequence of operator-reviewed extractions.

---

## 13. Integration with existing pipeline

```
                    ┌─────────────────────────────────────┐
                    │  External sources (v2 verifier)     │
                    └─────────┬───────────────────────────┘
                              │
                              ▼
  claim → reinforced_claim → fact_candidate ───┐
                                    │          │
                    (LLM extract    │          │
                     structured_claim)         │
                                    │          │
                    (Layer 1        │          │
                     consistency)   │          │
                                    ▼          │
                                canonical ◄────┘
                                    │
                    (Layer 2        │
                     entailment)    │
                                    ▼
                              derived_claim
                                    │
                    (awaits external corroboration)
                                    │
                    (match detected by v2 verifier)
                                    │
                    (Layer 1 consistency check)
                                    │
                                    ▼
                                canonical
```

Substrate lives on NODE at `~/.kestrel-node/runtime/substrate/`:

```
substrate/
├── substrate.db               # SQLite primary store
├── journal.jsonl              # append-only recovery log
├── extraction_audit.jsonl     # LLM extraction audit
├── consistency_check.sh       # Layer 1
├── entailment_engine.sh       # Layer 2
├── snapshot_to_git.sh         # nightly cron target
├── prompts/
│   └── extract_structured_claim.md
├── lib/
│   ├── schema.sql             # DB init
│   ├── predicates.sql         # seed vocabulary
│   ├── structured_claim.sh    # validation helpers
│   ├── provenance.sh          # provenance chain helpers
│   └── llm_extract.sh         # calls Claude API
└── tests/
    ├── test_layer1.sh
    ├── test_layer2.sh
    ├── test_storage.sh
    └── test_extraction.sh
```

Host console gains a **Reasoning** panel: derived_claims, conflicts awaiting resolution, derivation chains, extraction review queue.

---

## 14. Deliverables

- [ ] `docs/REASONING_SUBSTRATE_V0.md` — this spec, committed to repo
- [ ] `~/.kestrel-node/runtime/substrate/lib/schema.sql` — DB schema
- [ ] `~/.kestrel-node/runtime/substrate/lib/predicates.sql` — seed vocabulary (15 predicates)
- [ ] `~/.kestrel-node/runtime/substrate/lib/structured_claim.sh` — validation + write helpers
- [ ] `~/.kestrel-node/runtime/substrate/lib/provenance.sh` — provenance chain helpers
- [ ] `~/.kestrel-node/runtime/substrate/lib/llm_extract.sh` — Claude API caller
- [ ] `~/.kestrel-node/runtime/substrate/prompts/extract_structured_claim.md` — extraction prompt
- [ ] `~/.kestrel-node/runtime/substrate/consistency_check.sh` — Layer 1
- [ ] `~/.kestrel-node/runtime/substrate/entailment_engine.sh` — Layer 2
- [ ] `~/.kestrel-node/runtime/substrate/snapshot_to_git.sh` — nightly snapshot
- [ ] 7 derivation rules seeded in `rules` table
- [ ] `~/.kestrel-node/runtime/substrate/tests/` — full test suite per §11
- [ ] Integration hook in `run_promotion_queue.sh` for Layer 1
- [ ] Integration hook for canonical-addition trigger of Layer 2
- [ ] Integration hook in v2 verifier for derived_claim external-match detection
- [ ] Systemd timer for 03:00 NODE-local git snapshot
- [ ] Console panel: Reasoning
- [ ] Console action: Extract structured_claim (invokes LLM, displays review form)
- [ ] Schema migration: add `derived_claim` to allowed epistemic levels
- [ ] Backfill structured_claim for all current canonicals (deliverable completed, not merely enabled)

---

## 15. Prerequisites before starting build

1. verify_claims v2 must be in production and stable for at least one week.
2. LLM extraction pipeline (§9) must be working end-to-end before backfill (§12) begins.
3. Backfill must complete before Layer 2 goes live — entailment engine with zero structured canonicals has nothing to reason over.

**Do not start substrate build while v2 is still shadow-testing.** One doctrine-layer change at a time.

---

## 16. Handoff note to Claude Code

This spec has been operator-reviewed and all open questions resolved. Build in deliverable order from §14. Stop after each major component (DB + schema, LLM extraction, Layer 1, Layer 2, snapshot, console panel) for operator review. Do not enable hooks into production paths until explicitly approved.
