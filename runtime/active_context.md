# Active Context — Session 19 (2026-06-03)

## Architecture
- EC2 = primary; all pipeline logic, Bedrock calls, CC sessions
- NODE = CC memory/workspace only; no inference; kestrel-memory git auto-backup every 12h
- Bedrock Haiku 4.5 = sole inference layer (global.anthropic.claude-haiku-4-5-20251001-v1:0, us-east-1)

## Pipeline state

| Item | State |
|---|---|
| llama_ready/ | 2,506 total; 762 consumed, 1,744 not consumed |
| training/candidates/ | 1,831 CORROBORATED, all promoted=False (flag not updated by auto_promote) |
| offload_list.jsonl | 794 records CORROBORATED; safety filter correct (CORROBORATED check present) |
| staging/review_queue/ | 3,653 records, gate_status=none (review_loop stopped 2026-06-01) |
| runtime/validation_queue.jsonl | 4,899 records, gate_status=none |
| node-review-loop.timer | INACTIVE — stopped 2026-06-01; truth gate idle |
| EC2 ingest timers | All running 24/7 (S2 VN window restriction removed this session) |
| NODE ollama | Dead — intentionally retired |

## Completed this session (2026-06-03)
- S2 24hr fix: removed _within_ingest_window() VN-hours gate from semantic_scholar_ingest.py; set MIN_SECONDS_BETWEEN_S2_REQUESTS = 120 (was 62)
- Offload schema: confirmed offload_trained.py already has CORROBORATED in safe_batch filter — no fix needed
- Promotion leak audit: zero corpus_record nulls at gate-passed level across all pipeline stages; promoted flag in candidates is stale (auto_promote never writes it back)

## Pending — next session
1. Run offload with --force (794 records, CORROBORATED safe filter confirmed)
2. node-validate.service — 20 records in validation_queue, decide restart vs idle
3. 10 candidates to llama_ready — Rick authorization required before drain
4. Kestrel-memory restructure (~/kestrel/knowledge/) — Phase 5 carry-over
5. Firewall config — Session 14 carry-over
6. Fix promoted flag in auto_promote_to_llama_ready() — cosmetic but breaks auditing
