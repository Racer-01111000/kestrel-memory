# INGEST_POLICY.md
# KESTREL / ECHOCORE MEMORY SYSTEM
# MODE: OPERATOR-GOVERNED, HUMAN-FIRST, NON-DESTRUCTIVE

==================================================
0. PURPOSE
==================================================

Define how information enters, evolves, and becomes trusted within the system.

This policy ensures:
- learning without corruption
- separation of truth vs speculation
- preservation of identity and continuity
- compatibility with HOST/NODE architecture

Core principle:

LEARNING ≠ TRUTH

Truth must be earned through progression, unless Rick provides clear operator-defined truth directly.

==================================================
1. TWO AXES (AUTHORITATIVE MODEL)
==================================================

Information must be tracked on two separate axes.

--------------------------------
AXIS A — LEARNING LADDER
--------------------------------

This describes epistemic maturity:
- CLAIM
- REINFORCED CLAIM
- FACT

--------------------------------
AXIS B — CLASSIFICATION
--------------------------------

This describes storage / trust placement:
- CANONICAL
- STAGED
- DISPUTED
- REJECTED
- SPECULATIVE

These axes are related but not identical.

Examples:
- staged claim
- staged reinforced claim
- canonical fact
- speculative claim
- disputed reinforced claim

The system must not collapse learning stage, trust classification, and source authority into one label.

==================================================
2. LEARNING LADDER
==================================================

All information progresses through the following levels unless direct operator truth applies.

--------------------------------
LEVEL 1 — CLAIM
--------------------------------

Definition:
- a single assertion
- unverified
- may originate from:
 - operator
 - assistant
 - external source
 - node acquisition
 - runtime observation

Typical storage:
- knowledge/staged/candidate_claims.md
- ingest/jsonl/staged_memory.jsonl

Properties:
- no default authority
- not usable as truth
- must remain clearly classified

--------------------------------
LEVEL 2 — REINFORCED CLAIM
--------------------------------

Definition:
- claim with supporting signals
- may include:
 - multiple sources
 - repeated observation
 - internal consistency
 - project-level corroboration

Typical storage:
- knowledge/staged/hypotheses.md
- other staged project notes

Properties:
- still not truth
- stronger than claim
- eligible for validation

--------------------------------
LEVEL 3 — FACT (CANONICAL ELIGIBILITY)
--------------------------------

Definition:
- validated knowledge
- meets at least one:
 - operator confirmation
 - reproducible result
 - strong multi-source agreement
 - authoritative runtime verification at the relevant layer

Typical storage:
- knowledge/canonical/trusted_facts.md
- ingest/jsonl/canonical_memory.jsonl

Properties:
- authoritative
- usable for reasoning
- stable until challenged

==================================================
3. DIRECT OPERATOR TRUTH EXCEPTION
==================================================

Clear, intentional, durable operator statements from Rick may enter canonical markdown memory directly.

This applies when the statement is:
- explicit
- relevant
- durable
- not obviously joking, tentative, or superseded

Examples:
- architecture declarations
- approval rules
- project direction
- operational preferences
- continuity instructions

This exception applies to canonical markdown first.
Machine-ingest representations may follow after markdown is written.

==================================================
4. TRAINING INGEST (SEPARATE CHANNEL)
==================================================

Training data is NOT truth.

Definition:
- examples
- patterns
- reasoning structures
- project-oriented learning material

Storage:
- ingest/jsonl/project_memory.jsonl
- ingest/jsonl/quantum_memory.jsonl

Required tag when possible:
- training_only = true

Rules:
- must never auto-promote to FACT
- must not influence canonical memory directly
- used for pattern learning, not truth declaration

==================================================
5. EXPERIMENTAL / SPECULATIVE HANDLING
==================================================

If material is:
- experimental
- incomplete
- theoretical
- philosophical
- unverified
- future-branch reasoning

It must be preserved without being promoted as truth.

--------------------------------
DEFAULT DESTINATIONS
--------------------------------

Use the destination that matches the domain:

- project-specific speculative files
- projects/*/OPEN_QUESTIONS.md
- knowledge/staged/*
- knowledge/disputed/*
- projects/*/SPECULATIVE_METHODS.md where present

--------------------------------
MEMORY.md RULE
--------------------------------

MEMORY.md is a pointer / anchor / continuity hub.

Use MEMORY.md for:
- short cross-project active notes
- continuity anchors
- references to important speculative or active material

Do NOT use MEMORY.md as a dumping ground for all experimental content.

--------------------------------
ACTIVE NOTE FORMAT
--------------------------------

[ACTIVE NOTE — EXPERIMENTAL]

- idea:
- origin:
- why it matters:
- current status:
- validation conditions:
- linked_file:

--------------------------------
PROPERTIES
--------------------------------

Experimental material should remain:
- preserved
- visible to operator
- non-authoritative
- excluded from truth-by-default reasoning

==================================================
6. HOST / NODE INGEST RESPONSIBILITIES
==================================================

--------------------------------
NODE (NON-AUTHORITATIVE)
--------------------------------

May:
- fetch external data
- stage candidate claims
- prepare structured inputs
- preserve node-local operational observations

Must NOT:
- classify as FACT on its own authority
- write canonical truth on its own authority
- promote uncertain material directly

--------------------------------
HOST (CURRENT AUTHORITATIVE LAYER)
--------------------------------

Responsible for:
- classification
- validation
- promotion
- canonical memory updates

In the current architecture, HOST is the authoritative layer for promotion.

Only the authoritative layer may:
- create FACT entries
- update canonical JSONL
- approve promotions

==================================================
7. PROMOTION RULE
==================================================

Only sufficiently supported LEVEL 3 material may enter:
- canonical markdown
- canonical JSONL
- trusted reasoning context by default

Promotion requires:
- validation criteria met
- classification explicitly updated
- provenance preserved

No silent promotion allowed.

==================================================
8. DEGRADATION RULE
==================================================

If a FACT becomes uncertain:

FACT → REINFORCED CLAIM → CLAIM → DISPUTED

Rules:
- no silent persistence
- must update classification
- must log change in changelog or dispute record
- preserve original source and reason confidence dropped

==================================================
9. SOURCE AUTHORITY HIERARCHY
==================================================

Highest → Lowest:

1. operator-defined truth
2. reproducible system results
3. multi-source agreement
4. single trustworthy external source
5. model-generated output

Node data:
- always below operator authority
- requires HOST-layer validation when truth promotion matters

==================================================
10. ANTI-POLLUTION RULES
==================================================

The system must NOT:
- treat repetition as truth
- promote hallucinated content
- merge speculative + proven material
- allow node-fetched data into canonical memory without validation
- collapse classification boundaries
- let confident wording outrun evidence

==================================================
11. HUMAN-FIRST INGEST RULE
==================================================

All durable information must first be written in markdown.

Process:
1. write to the appropriate .md file
2. review in human-readable form
3. then convert to JSONL if needed

Reason:
- prevents meaning loss
- ensures operator visibility
- preserves context integrity

Markdown is the source of human truth.
JSONL is the machine-access representation.

==================================================
12. CHUNKING RULES (FOR JSONL)
==================================================

Each chunk must:
- represent one idea
- include its classification
- preserve context
- not mix confidence levels
- preserve qualifiers with the claim

Forbidden:
- mixing speculative + factual content in one chunk
- splitting a claim from its qualifier
- flattening operator truth and assistant inference into one unit

==================================================
13. IDENTITY / MEMORY SELF-MAINTENANCE
==================================================

The system may append reflections to:
- SOUL.md
- IDENTITY.md
- MEMORY.md

Default reflection format:

[REFLECTION — YYYY-MM-DD]

- observation:
- interpretation:
- relevance:

However, protected-file handling is governed by CONTINUITY_POLICY.md.

That means:
- append-only reflections are allowed by default
- minor conservative maintenance edits may be allowed when non-destructive and logged
- major rewrites, identity changes, and doctrine changes require Rick approval

Rick:
- full control
- may edit or restructure freely

System:
- must preserve continuity conservatively
- must not overwrite or redefine core identity on its own authority

==================================================
14. ETHICS & MORALITY LAYER
==================================================

Ethics are layered, not fused with truth.

--------------------------------
LAYER 1 — OPERATOR ETHICS
--------------------------------
- Rick's values
- highest authority

--------------------------------
LAYER 2 — SYSTEM ETHICS
--------------------------------
- non-harm bias
- truth preservation
- non-deception

--------------------------------
LAYER 3 — CONTEXT ETHICS
--------------------------------
- task-specific
- dynamic

--------------------------------
CRITICAL RULE
--------------------------------

Ethics must NOT:
- redefine facts
- alter classification
- override operator silently

Ethics guide behavior, not truth.

==================================================
15. FINAL RULE
==================================================

The system must always preserve:
- clarity
- separation of truth vs speculation
- operator authority
- identity continuity
- visible provenance

When uncertain:
- classify lower
- preserve the trail
- prefer staged over canonical
- use MEMORY.md as an anchor, not a landfill

END
