# UI CLEANUP + DIALOGUE RETRIEVAL — Specification

**Status:** FINALIZED, ready for CC handoff
**Revision:** v0.5.1 — folds in operator decisions on LRU cap, log rotation, retrieve-anyway deferral, and TOS mechanism
**Target location in repo:** `docs/UI_DIALOGUE_V0.5.md`
**Combines:**
- Deliverable A — UI consistency pass (schema drift cleanup)
- Deliverable B — Dialogue box retrieval on unknowns with automatic staging
**Depends on:** verify_claims v2 stable in production
**Predecessor to:** Dialogue Box v1.0 (authority-promote integration — lands with substrate v0)

---

## 1. Purpose

Two problems, one spec because they share the same surface (the operator console):

**Problem 1: schema drift in the console.** The ingest dropdown offers epistemic-level values (`verified`, `hypothesis`, `disputed`) that don't exist in the pipeline. The staged-items count reads from a stale node-mirror. The pipeline-state pane shows a 2026-03-31 timestamp with no staleness indicator. These drifts compound — building new features on top of inconsistent primitives produces more inconsistency.

**Problem 2: the dialogue box is inert.** It accepts queries but cannot retrieve anything not already in the corpus. That makes it a corpus-search tool dressed as a dialogue tool. What it should be: a **query-driven corpus growth mechanism** — asking a question is how unknowns become knowns. Gaps in the knowledge base drive acquisition.

v0.5 fixes the drift (Deliverable A), then wires dialogue retrieval to v2's witness sources with automatic staging of novel results (Deliverable B). Authority-promotion from dialogue, and staging-schema integration with substrate's `structured_claim`, arrive in Dialogue Box v1.0 alongside substrate v0.

---

## 2. Doctrine note: corpus growth is query-driven

This spec introduces a small but real doctrinal addition:

> **Asking is acquiring.** When the operator queries the dialogue box for knowledge Kestrel does not yet hold, and retrieval returns a novel claim from an approved source, that claim is staged automatically. The operator's question *is* the acquisition trigger. Consent to this mechanism is granted by the operator's Terms of Service acceptance, not by per-query confirmation.

This does not weaken the existing doctrine (`Acquisition ≠ Evidence ≠ Sufficiency ≠ Promotion ≠ Derivation ≠ Observation`) — staging is still just acquisition. The new claim enters at `epistemic_level: claim` and must still pass v2 verification to reach `fact_candidate`, and Layer 1 + host approval to reach canonical. Automatic staging accelerates acquisition; it does not shortcut any downstream gate.

The "Asking is acquiring" clause is included verbatim in the TOS document (§5.4) so that the operator's acceptance is consent to this specific doctrine, not a generic ToS checkbox.

---

## 3. Deliverable A — UI Consistency Pass

### 3.1 Ingest dropdown cleanup

**Current state:** dropdown offers `claim | fact_candidate | hypothesis | verified | disputed`.

**Problem:** `verified`, `hypothesis`, `disputed` are not pipeline epistemic levels. `verified` has already produced one stuck staged item (ingest__20260418_101404.json) that no downstream handler can process correctly. `hypothesis` and `disputed` have no downstream handlers at all.

**Fix:** restrict dropdown to values that are legal ingest-time epistemic levels:

- `claim` — default, raw input
- `fact_candidate` — operator asserts the material already qualifies for verification-gate review (subject to v2 catching any problems)

Nothing else is an ingest-time value. `reinforced_claim`, `canonical`, `derived_claim` are promotion outcomes, not ingest inputs.

**Stuck-item handling:** the existing item at `epistemic_level: verified` gets reclassified to `fact_candidate` as part of this deliverable. One-line script, committed with the UI change.

### 3.2 Staged-items count

**Current state:** console reads from `node-mirror/knowledge/staged/` which is synced periodically; shows 13 while actual NODE has 19.

**Fix:** `/api/staged` endpoint SSHes to NODE and reads the live directory directly. Mirrors the pattern already used by `/api/promotion_gate`. Reuses SSH session if one is already open.

**Caching:** 30-second in-memory cache to avoid hammering NODE on every panel refresh. Cache bypassed if operator hits an explicit refresh button.

### 3.3 Pipeline-state staleness indicator

**Current state:** pipeline-state pane displays the `updated` timestamp from `resume_state.json` with no visual cue that it's stale. The current timestamp is 2026-03-31 — 18 days old.

**Fix:** traffic-light indicator next to the timestamp:

- Green — `updated` within last 24 hours
- Amber — 24 hours to 7 days
- Red — older than 7 days, with tooltip "Pipeline state pane reflects persisted job state, not live operational state. Last update <N> days ago."

Thresholds are intentionally loose — this is a "pay attention" signal, not a hard failure indicator.

### 3.4 Scope boundary

This deliverable is *only* drift cleanup. No new features. No re-layout. No theming changes.

### 3.5 Testing

- Confirm ingest dropdown shows exactly two values (`claim`, `fact_candidate`).
- Submit ingest with each and confirm items enter staged/ with the correct epistemic_level.
- Confirm `/api/staged` returns 19 (current live NODE count) within 2 seconds of request.
- Confirm staleness indicator goes green / amber / red at the specified thresholds (inject fixture timestamps).
- Confirm reclassified item (was `verified`) now reads `fact_candidate` and v2 picks it up on next timer fire.

---

## 4. Deliverable B — Dialogue Box Retrieval with Automatic Staging

### 4.1 Flow

```
Operator types query in dialogue box
          │
          ▼
TOS acceptance check (§5)
  ├─ not accepted → block submission, show TOS modal, abort
  └─ accepted → proceed
          │
          ▼
Console submits query to /api/dialogue/query
          │
          ▼
NODE: corpus_match_check(query)   [heuristic, v0.5; semantic in v1.0]
  ├─ match found in canonical  → return canonical answer, done
  ├─ match found in staged     → return staged answer + "already in verification queue" flag, done
  └─ no match                  → proceed to retrieval
          │
          ▼
NODE: v2_witness_retrieval(query)
  ├─ arXiv API      }
  ├─ Crossref       }  primary retrieval
  ├─ OpenAlex       }  (reuses lib/sources.sh from verify_claims v2)
  ├─ Semantic Scholar
  ├─ INSPIRE-HEP
  └─ NIST/CSRC
          │
          ▼
Any v2 source returns hits?
  ├─ YES → stage_silently(each_hit) + return hits to console
  └─ NO  → w3m_fallback(query)
              │
              ▼
         w3m returns content?
           ├─ YES → stage_silently(content) + return to console
           └─ NO  → return "No results found" to console
          │
          ▼
Console displays results inline in dialogue
  Each result has: [Erase] button
  (Leaving result untouched = keep in queue, standard v2 verification proceeds)
```

### 4.2 Retrieval precedence: v2 first, w3m last

**Rationale:** v2 witness sources are structured APIs returning clean metadata and abstracts. w3m is full-page HTML scraping against the general web. v2 is better for anything v2 can answer.

**Silent reject:** if v2 returns content that matches an item already in canonical or staged (determined by normalized title + source URL), that result is NOT re-surfaced to the operator and NOT re-staged. The dialogue response may indicate "answer available in corpus" but does not duplicate the item.

**w3m as fallback only:** invoked only when *all* v2 sources return zero hits. This is the escape hatch for queries v2's scholarly-focused sources genuinely cannot answer (news events, vendor documentation not in NIST/CSRC, general-web content). w3m's brittleness is acceptable here because it's the last-resort path, not the default path.

### 4.3 Automatic staging (TOS-governed)

**Default behavior:** any novel result from v2 retrieval is staged automatically as a new `staged/` item at `epistemic_level: claim`. The operator is NOT prompted per-query.

**Staged item format:**

```json
{
  "ingest_id": "dialogue_<query_hash>_<timestamp>",
  "epistemic_level": "claim",
  "source": "dialogue_retrieval",
  "dialogue_context": {
    "query": "<operator's original query>",
    "query_submitted_at": "2026-04-18T13:45:00Z",
    "retrieval_source": "crossref | arxiv | openalex | semantic_scholar | inspire | nist | w3m",
    "source_url": "<url of retrieved content>",
    "source_title": "<title of retrieved item>"
  },
  "title": "...",
  "content": "...",
  "review_status": "pending"
}
```

`dialogue_context` distinguishes dialogue-retrieval items from manual-ingest items, so the audit trail shows how each claim entered the corpus.

### 4.4 Erase action

**Operator-triggered hard delete:** when the operator clicks Erase on a dialogue result, the staged item is deleted from disk. Not retired, not moved to a trash folder — deleted.

**Rationale:** NODE storage is at a premium. Cloud expansion is planned but not imminent. Retained "rejected" items would accumulate without bound, and the operator has explicitly requested hard discard.

**Hash trace:** on erase, write a single line to `~/.kestrel-node/runtime/erased_hashes.log`:

```
2026-04-18T13:47:22Z  <sha256(source_url)>  <sha256(normalized_title)>  <query_hash>
```

~80 bytes per erase. Purpose: on subsequent dialogue queries, retrieval results whose URL or title hash matches a recent erase are suppressed from the operator's view. This prevents the same low-quality result from resurfacing on similar queries and being erased repeatedly.

**LRU configuration:**

- Config knob: `config.hash_log_lru_max` (default: 10000)
- Eviction strategy: entry-count LRU (not time-based)
- On insert exceeding cap, evict least-recently-used entries deterministically
- 10000 entries × ~80 bytes = ~800KB — trivial on NODE
- Configurable for heavier workloads (recommended upper bound for NODE: 100000)

**No content retained:** the hash log stores only hashes, never content. An erased claim is genuinely gone from disk; only its fingerprint remains to prevent immediate re-surfacing.

### 4.5 "Leave in queue" as the default non-action

If the operator does nothing with a dialogue result, the staged item remains in the queue and proceeds through v2 verification on the next timer fire. This is the default path and needs no explicit UI affordance — the result is already staged by the time the operator sees it.

The dialogue response labels each result **"Queued for verification"**, so the operator understands they need to take explicit action (Erase) if they *don't* want it in the queue.

### 4.6 Corpus match check

**v0.5 implementation:** keyword heuristic match.

1. Normalize query (lowercase, strip stopwords, tokenize).
2. For each token of length ≥4, check whether it appears in any canonical or staged item's `title` or `content` (case-insensitive).
3. If ≥3 distinct tokens match in a single existing item → treat as corpus match, suppress retrieval, return that item as the answer.

This is crude and will produce false positives and false negatives. The spec acknowledges this explicitly; the retrieve-anyway behavior is handled in §4.7.

**v1.0 replacement (when substrate ships):** semantic match via `structured_claim`. Query gets LLM-extracted into a candidate structured_claim, then the substrate searches for canonical items with matching predicate + subject. Much more accurate, unavailable until substrate v0 ships.

### 4.7 "Retrieve anyway" handling — Advanced Mode only

**No first-class button in v0.5.** A prominent override would train reflexive override use during the period when the corpus matcher is known-crude, entrenching a habit that outlives the crudeness.

**Advanced Mode mechanism:**

- Console has a settings toggle: `Advanced mode: ON / OFF`
- Default: OFF
- Toggle state persists across sessions (per-operator)
- Every flip of the toggle is logged to `~/.kestrel-node/runtime/advanced_mode_toggles.log` with timestamp and operator identity

**When Advanced Mode is ON:**

- An additional affordance appears on corpus-match responses: **"Retrieve anyway"**
- Using this affordance logs to `~/.kestrel-node/runtime/advanced_overrides.log`:
  ```
  <iso8601_timestamp>  override=retrieve_anyway  query=<query_hash>
  matched_item=<canonical_or_staged_id>  reason=<operator_supplied_text_or_empty>
  ```
- Operator is prompted for an optional reason at override time
- Retrieve anyway bypasses the corpus-match suppression and performs v2 retrieval as if no match existed

**Minimal v0.5 fallback for non-Advanced users:** a "retry with verbatim terms" option is always available (no Advanced Mode required). This re-runs corpus-match using the operator's exact query string with no stopword stripping or tokenization. Less policy-breaking than full override; catches the case where stopword stripping caused a false positive match.

**Path to v1.0:** once semantic match lands with substrate v0, a proper first-class "Retrieve anyway" button can be added, with its own reason-logging and review semantics. The Advanced Mode path remains for even-further overrides.

### 4.8 Rate limits and quotas

**v2 witness source calls:** same rate discipline as verify_claims v2. Minimum 1 second between same-source calls. Per-source timeouts at 15 seconds. Skip-on-429.

**w3m fallback:** single call per query. Hard timeout 20 seconds. If w3m times out, return "No results found" — don't retry.

**Per-operator query rate:** no hard limit in v0.5, but every dialogue query is logged per §4.9.

### 4.9 Query logging and rotation

**Active log file:** `~/.kestrel-node/runtime/query.log`

**Log entry format:** one line per query, containing timestamp, query text, retrieval path (v2 vs w3m), hit count, staged count, TOS acceptance state.

**Rotation rules:**

- **Monthly rotation:** at the start of each calendar month, `query.log` is renamed to `query-YYYY-MM.log` and a fresh active file is created.
- **Size-cap early rotation:** if `query.log` exceeds **20MB** at any rotation check, it is rotated immediately (file named with current month and a sequence suffix if a monthly rotation has already occurred, e.g., `query-2026-04.2.log`).
- **Retention:** most recent 3 monthly archive files retained on NODE. Older archives deleted.
- **Rotation trigger:** rotation logic runs as part of the nightly 03:00 NODE-local cron (same window as substrate snapshot). Each run checks: (a) is it a new month? (b) is the active file >20MB? Either condition triggers rotation.
- **Long-term audit:** if the operator requires indefinite query history, a future deliverable exports archived logs to HOST. NOT part of v0.5. Raw query logs are not intended to persist forever on NODE.

### 4.10 Console changes

**Dialogue panel (existing):** retains its current input affordance.

**New response affordances per retrieval result:**

- Result title + snippet (linked to source URL, opens in new tab)
- Source badge: [crossref] / [arxiv] / [openalex] / [semantic_scholar] / [inspire] / [nist] / [w3m]
- Status label: "Queued for verification" (default) or "Already in corpus" (if corpus match)
- [Erase] button per result
- [Retry with verbatim terms] button on corpus-match responses (always available)
- [Retrieve anyway] button on corpus-match responses (Advanced Mode only)

**New settings area:** one item in v0.5 — `Advanced mode: ON / OFF` toggle.

**No changes to other panels in this deliverable.** Reasoning panel, promotion gate, etc. remain untouched.

### 4.11 New endpoints

- `POST /api/dialogue/query` — accepts query, returns retrieval results + auto-staged status. Blocks if TOS not accepted.
- `POST /api/dialogue/erase` — erases a specified staged dialogue item, writes to hash log.
- `POST /api/dialogue/retry_verbatim` — re-runs corpus match with verbatim query string.
- `POST /api/dialogue/retrieve_anyway` — bypasses corpus match. Advanced Mode required. Logs override.
- `GET /api/settings/advanced_mode` — returns current state.
- `POST /api/settings/advanced_mode` — toggles state, logs flip.
- `GET /api/tos/status` — returns TOS acceptance state for current operator.
- `POST /api/tos/accept` — records TOS acceptance with version and timestamp.

All endpoints require standard console session (no unauthenticated access).

### 4.12 New NODE scripts

- `~/kestrel-memory/runtime/dialogue_query.sh` — primary handler called by console
  - Orchestrates: corpus match → v2 retrieval → w3m fallback → staging
  - Reuses `lib/sources.sh` from verify_claims v2 (do not duplicate the source functions)
- `~/kestrel-memory/runtime/corpus_match.sh` — heuristic keyword-match helper
- `~/kestrel-memory/runtime/erase_dialogue_item.sh` — handles erase action + hash log append
- `~/kestrel-memory/runtime/retrieve_anyway.sh` — Advanced-Mode override path
- `~/kestrel-memory/runtime/rotate_query_log.sh` — called by nightly cron for log rotation

---

## 5. TOS Acceptance Mechanism

No existing TOS flow in the console. v0.5 defines and implements a minimal one.

### 5.1 TOS document location

**Canonical path:** `~/.openclaw/workspace/TOS.md` on HOST, tracked in git alongside other doctrine documents (SOUL.md, IDENTITY.md, CONTINUITY_POLICY_V2_DRAFT.md, TRUST_MODEL_V2_DRAFT.md, persona/USER.md).

**Rationale:** the TOS is doctrine, not boilerplate. Tracking it in the same repo as other doctrine documents means it is versioned, diffable, and protected by the existing identity_guard mechanism (same auto-revert-without-confirmation protection as other doctrine files).

**Version:** derived from a version header at the top of the file:

```markdown
# Kestrel Terms of Service
**Version:** 2026-04-18.1
**Effective:** 2026-04-18
**Commit hash:** <git short hash, computed at read time>
```

Both a human-readable date-stamp version and the git commit hash. The commit hash is authoritative for acceptance tracking; the date-stamp version is for operator display.

### 5.2 Acceptance storage

**Storage file:** `~/.kestrel-node/runtime/tos_acceptances.json`

**Schema:**

```json
{
  "acceptances": [
    {
      "operator": "rick",
      "tos_version": "2026-04-18.1",
      "tos_commit_hash": "abc1234",
      "accepted_at": "2026-04-18T13:45:00Z",
      "accepted_from_ip": "100.76.5.44"
    }
  ]
}
```

Stored on NODE (not HOST) because acceptance is a per-operational-instance event. HOST retains the canonical TOS document; NODE retains acceptance history.

**For single-operator local setups** (current Kestrel configuration): local NODE persistence is sufficient. If cloud expansion introduces multi-operator scenarios, acceptance storage migrates server-side at that time.

### 5.3 Acceptance flow

**First use (no acceptance on record for current TOS version):**

1. On first load of console, fetch TOS via `GET /api/tos/status`.
2. If no acceptance matching current TOS commit hash, show blocking modal:
   - Display full TOS.md contents (rendered markdown)
   - Checkbox: `I have read and agree to these terms.`
   - Button: `Accept and continue` — disabled until checkbox ticked
   - Button: `Decline` — closes the modal, keeps retrieval/execution actions disabled
3. On accept: POST to `/api/tos/accept` with current commit hash; record appended to `tos_acceptances.json`.
4. Modal dismisses; retrieval and execution actions become enabled.

**TOS version bump (existing operator, new TOS version published):**

1. On load, `GET /api/tos/status` reports: accepted previous version, current version not accepted.
2. Show blocking modal with:
   - Diff between accepted version and current version, highlighted
   - Full current TOS (rendered below the diff)
   - Checkbox + Accept button as above
3. Until new version accepted, retrieval and execution actions are disabled.

**Actions gated by TOS acceptance:**

- Dialogue retrieval (any `/api/dialogue/*` endpoint)
- Any future execution actions (reserved term for forthcoming deliverables)

**Actions NOT gated by TOS:**

- Read-only corpus browsing, promotion gate viewing, pipeline state viewing
- Existing manual-ingest flow (pre-existing behavior, unchanged)
- Telegram bot commands (separate consent surface; gating Telegram is a separate future deliverable)

### 5.4 Required TOS content

The TOS.md document must include, at minimum:

1. **Automatic staging clause:** the "Asking is acquiring" doctrine (§2 of this spec, verbatim) — operator queries may trigger automated retrieval and staging of external content.
2. **Retention clause:** staged dialogue items may be erased by the operator at any time; erasure is hard delete with only a hash fingerprint retained to prevent immediate re-surfacing.
3. **Verification clause:** no content reaches canonical without explicit host approval regardless of how it was staged.
4. **Logging clause:** all dialogue queries, advanced-mode toggles, and advanced overrides are logged for audit purposes.
5. **Doctrine reference:** pointer to the core doctrine document (SOUL.md or equivalent) — operator acknowledges they have read and agree to the broader doctrine, not just this TOS.

Drafting of TOS.md content is operator-owned, not a CC deliverable. CC builds the mechanism; operator writes the document.

### 5.5 Testing

- Fresh NODE with no acceptance record → first console load shows TOS modal, retrieval actions disabled.
- Accept TOS → actions enabled, acceptance persisted to `tos_acceptances.json`.
- Reload console → no modal shown, actions enabled.
- Bump TOS version (update TOS.md + commit) → next load shows diff modal, actions disabled until re-accepted.
- Attempt `POST /api/dialogue/query` without acceptance → 403 response with `reason: tos_not_accepted`.

---

## 6. Explicit non-goals for v0.5

To prevent scope drift:

- **No authority-promote action from dialogue.** That arrives in Dialogue Box v1.0 alongside substrate v0 §9.
- **No `structured_claim` extraction at dialogue time.** That arrives with substrate v0 §10.
- **No first-class "Retrieve anyway" button.** Advanced-Mode-only in v0.5 per §4.7.
- **No dialogue context persistence across sessions.** v0.5 does not retain dialogue history. Each query is atomic.
- **No multi-turn dialogue.** Single query → single retrieval response.
- **No ranking or quality scoring of retrieval results.** Results returned in v2-source order.
- **No UI changes beyond the dialogue panel, the Advanced Mode toggle, the TOS modal, and the three items in Deliverable A.** All other console panels stay as they are.
- **No long-term query log export to HOST.** Monthly rotation + 3-archive retention on NODE only in v0.5. Long-term audit export is a future deliverable.
- **No multi-operator TOS acceptance.** Single-operator local persistence only. Server-side storage is a future deliverable.

---

## 7. Failure modes

| Failure | Mitigation |
|---|---|
| **Retrieval storm** — operator submits many queries quickly, each triggering 6 v2 sources + possible w3m | v2 source rate-limits inherited from verify_claims v2; query.log makes abuse visible |
| **Stale corpus-match suppresses useful retrieval** | Retry-verbatim always available; Advanced Mode retrieve-anyway for deeper override; semantic match in v1.0 |
| **Automatic staging floods queue** — novel but low-quality results accumulate in staged/ | Operator uses Erase; hash log prevents re-staging of erased items |
| **Erased-hash collision** — two distinct items hash to same fingerprint | Extremely rare with sha256 on url+title; worst case = one false suppression; operator can clear hash log manually |
| **w3m fallback returns hostile content** | w3m results staged at `claim`, not auto-promoted; v2 verification will fail on non-primary-source material; operator can Erase |
| **TOS not accepted** | Console blocks dialogue submission at modal; retrieval endpoints return 403 if bypassed |
| **TOS version drift** — doctrine updated but operator hasn't re-accepted | Version bump detection forces re-acceptance on next load with diff displayed |
| **Advanced Mode left ON indefinitely** — operator forgets, reflexively uses retrieve-anyway | Every flip and every override logged; console displays persistent indicator when Advanced Mode is ON |
| **Query log fills NODE disk** | Size-cap rotation at 20MB + retention of only 3 monthly archives |
| **Hash log grows past configured cap** | LRU eviction maintains cap; default 10000 ≈ 800KB is trivially small |
| **NODE disk pressure from staged flood** | Erase is hard delete; dialogue-staged items tagged with `source: dialogue_retrieval` for easy bulk-cleanup if needed |

---

## 8. Testing plan

### 8.1 Deliverable A tests

Covered in §3.5.

### 8.2 Deliverable B happy-path tests

**Corpus match:**
- Submit query matching existing canonical item's title → response returns canonical answer, no retrieval, no new staging.

**v2 retrieval:**
- Submit query about a quantum topic not in corpus → response shows ≥1 v2-source result → new staged item exists with `source: dialogue_retrieval` → next v2 timer picks it up.

**w3m fallback:**
- Submit query v2 cannot answer → response shows w3m result → staged with `retrieval_source: w3m`.

**Erase:**
- Submit query, receive result, click Erase → staged item deleted → hash log gains entry → similar query → same result suppressed.

**Silent corpus reject:**
- Submit query, v2 returns hit matching existing staged item → response indicates "already in corpus", no duplicate staged.

### 8.3 Advanced Mode tests

- Advanced Mode OFF → no retrieve-anyway affordance shown.
- Toggle ON → affordance appears; toggle logged.
- Retrieve-anyway on corpus match → bypass succeeds; override logged with reason.
- Toggle OFF → affordance disappears; toggle logged.

### 8.4 Retry-verbatim tests

- Query with stopwords causes false-positive corpus match → retry-verbatim → different match result (or no match, triggering retrieval).

### 8.5 TOS tests

- Covered in §5.5.

### 8.6 Log rotation tests

- Fixture `query.log` at 21MB → nightly rotation fires → archived, fresh active file created.
- 4 monthly archives present → nightly rotation → oldest deleted, 3 retained.
- Calendar month rollover fixture → rotation fires at cron time regardless of file size.

### 8.7 Rate limiting tests

- 20 rapid queries → v2 sources honor rate limits → no 429 cascade → query.log records all 20.

---

## 9. Deliverables checklist

**Deliverable A (UI Cleanup):**

- [ ] Ingest dropdown restricted to `claim | fact_candidate`
- [ ] Reclassify stuck `verified` item to `fact_candidate`
- [ ] `/api/staged` reads live NODE directory
- [ ] Staleness indicator on pipeline-state pane (green/amber/red)
- [ ] `/api/staged` 30-second cache with bypass-on-refresh
- [ ] Deliverable A tests pass (§3.5)

**Deliverable B — P0 (must ship):**

- [ ] `~/kestrel-memory/runtime/dialogue_query.sh` orchestrator
- [ ] `~/kestrel-memory/runtime/corpus_match.sh` heuristic matcher
- [ ] `~/kestrel-memory/runtime/erase_dialogue_item.sh` erase handler
- [ ] `~/kestrel-memory/runtime/rotate_query_log.sh` log rotation
- [ ] Reuse of `lib/sources.sh` from verify_claims v2 (no duplication)
- [ ] w3m fallback path wired in as last resort
- [ ] `POST /api/dialogue/query` endpoint with TOS gate
- [ ] `POST /api/dialogue/erase` endpoint
- [ ] `POST /api/dialogue/retry_verbatim` endpoint
- [ ] `GET/POST /api/tos/status`, `/api/tos/accept` endpoints
- [ ] TOS modal component (first-use + version-bump flows)
- [ ] TOS version detection via TOS.md git commit hash
- [ ] `~/.kestrel-node/runtime/tos_acceptances.json` storage
- [ ] Console dialogue panel: result display with source badges, status labels, Erase buttons
- [ ] Hash log at `~/.kestrel-node/runtime/erased_hashes.log`
  - Configurable LRU cap via `config.hash_log_lru_max` (default 10000)
  - Entry-count LRU eviction, deterministic
- [ ] Query log at `~/.kestrel-node/runtime/query.log`
  - Monthly rotation
  - 20MB size-cap early rotation
  - Retention of 3 monthly archives
  - Nightly cron at 03:00 NODE-local
- [ ] Systemd timer for log rotation (or reuse existing nightly cron if available)
- [ ] P0 tests pass (§8.1, §8.2, §8.5, §8.6, §8.7)

**Deliverable B — P1 (should ship, can defer by days if P0 slips):**

- [ ] Advanced Mode toggle in console settings
- [ ] `GET/POST /api/settings/advanced_mode` endpoints
- [ ] `~/.kestrel-node/runtime/advanced_mode_toggles.log`
- [ ] Advanced Mode persistent indicator in console header when ON
- [ ] `POST /api/dialogue/retrieve_anyway` endpoint
- [ ] `~/kestrel-memory/runtime/retrieve_anyway.sh` override script
- [ ] `~/.kestrel-node/runtime/advanced_overrides.log`
- [ ] Retrieve-anyway affordance in dialogue UI (visible only when Advanced Mode ON)
- [ ] Reason-prompt modal on retrieve-anyway invocation
- [ ] P1 tests pass (§8.3, §8.4)

**Deliverable B — P2 (future, NOT v0.5):**

- [ ] First-class "Retrieve anyway" button with review semantics (v1.0)
- [ ] Long-term query log export to HOST (future deliverable)
- [ ] Server-side TOS acceptance storage (future, when multi-operator lands)

**Documentation:**

- [ ] Operator writes TOS.md content at `~/.openclaw/workspace/TOS.md` per §5.4 requirements
- [ ] This spec committed to `docs/UI_DIALOGUE_V0.5.md`
- [ ] Commit message: `feat(ui+dialogue): v0.5 — schema drift cleanup + dialogue retrieval with auto-staging`

---

## 10. Sequencing

Deliverable A ships first, independently. It's a drift fix, not a feature. Can land this week regardless of v2 stabilization window.

Deliverable B P0 ships after Deliverable A AND after verify_claims v2 has been stable for at least 48 hours. Rationale: Dialogue B depends on v2's `lib/sources.sh` being solid. A day or two of v2 production runs is enough to surface any source-function bugs before the dialogue layer hits them harder.

Deliverable B P1 (Advanced Mode) can ship in the same release window as P0 if time permits, or within 48–72 hours of P0 landing. It is not a hard blocker for P0 release because retry-verbatim (P0) handles the common false-positive case.

TOS.md document content (operator-owned) must exist before Deliverable B P0 can be tested against real acceptance flows. Minimum viable TOS.md can be drafted in an afternoon.

Dialogue v1.0 (authority-promote integration, structured_claim extraction, first-class "Retrieve anyway") ships with substrate v0 and is specified in REASONING_SUBSTRATE_V0.md §9 and §10, not here.

---

## 11. Implementation priority summary

**P0 — must ship in v0.5:**

1. TOS acceptance gate (mechanism + file + storage + modal)
2. Hash-log LRU configuration and eviction
3. Monthly query log rotation with size cap and retention
4. All of Deliverable A
5. Dialogue retrieval core (v2 sources + w3m fallback + auto-staging + Erase + retry-verbatim)

**P1 — should ship in v0.5, can slip by days:**

1. Advanced Mode toggle + retrieve-anyway override + override logging

**P2 — deferred to v1.0 or later:**

1. First-class "Retrieve anyway" UI with review semantics
2. Long-term query log export to HOST
3. Server-side TOS acceptance (when multi-operator lands)

---

## 12. Handoff note to Claude Code

v0.5.1 combines two small, related pieces of work: schema-drift cleanup (Deliverable A) and dialogue retrieval with auto-staging (Deliverable B). Ship in that order.

Deliverable A can proceed immediately. Deliverable B P0 waits for verify_claims v2 to be stable for at least 48 hours.

Key design anchors, do not deviate:

- Dialogue uses v2 witness sources FIRST, w3m ONLY as fallback. Do not substitute w3m as primary.
- Automatic staging is TOS-governed. No per-query consent prompt.
- Erase is hard delete, not soft-delete. Hash log retains fingerprint only.
- Hash log uses entry-count LRU with configurable cap (default 10000). Not time-based eviction.
- Query log rotates monthly with 20MB size cap, retains 3 archives. Not indefinite.
- "Retrieve anyway" is Advanced Mode only in v0.5. No first-class button. Retry-verbatim is the default override path.
- TOS is a real gate, not a stub. TOS.md lives in HOST repo under identity_guard protection. Acceptance storage on NODE. Version detection via git commit hash.
- No `structured_claim` extraction in v0.5. That's substrate v0 work.
- No authority-promote action from dialogue in v0.5. That's substrate v0 §9 work.

Stop for operator review after Deliverable A before starting Deliverable B. Stop again after Deliverable B P0 endpoints before wiring the console UI. Stop again before wiring Advanced Mode (P1).

---

## 13. Open questions — RESOLVED

The four open questions from the v0.5 draft are resolved:

1. **Hash-log LRU cap:** default 10000, configurable via `config.hash_log_lru_max`, entry-count LRU eviction.
2. **Query log rotation:** monthly + 20MB size cap + retain 3 monthly archives on NODE. Long-term export to HOST is future work.
3. **Retrieve-anyway override:** deferred as first-class button to v1.0. Advanced Mode (P1) is the v0.5 override path, with full logging. Retry-verbatim available to all operators.
4. **TOS acceptance mechanism:** full spec provided in §5. TOS.md on HOST under identity_guard protection, acceptance storage on NODE, version detection via git commit hash, first-use modal + version-bump re-acceptance flow.
