#!/usr/bin/env python3
"""
LLaMA consumer for NODE training/llama_ready/ pipeline.

Reads training/candidates/ for corroborated papers, optionally promotes
operator-approved candidates to training/llama_ready/, then sends them
to a selected backend for embedding/ingestion.

Two modes:
  --promote <paper_id>   Operator-triggered: move candidate -> llama_ready
  --consume              Process llama_ready records via node/Ollama or Bedrock
  --status               Show pipeline state

Default backend is node/Ollama. Bedrock backend is used only when explicitly selected.
Does NOT auto-promote. Promote is always explicit operator action.
"""
import argparse
import json
import os
import random
import shutil
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError
except Exception:
    boto3 = None
    BotoCoreError = Exception
    ClientError = Exception


BASE = Path.home() / "NODE"
CANDIDATES_DIR = BASE / "training/candidates"
LLAMA_READY_DIR = BASE / "training/llama_ready"
LATEX_DIR = BASE / "training/llama_ready_latex"
OFFLOAD_LIST = BASE / "runtime/offload_list.jsonl"
CONSUME_LOG = BASE / "metadata/ingest_logs/llama_consume.log"

OLLAMA_URL = "http://100.68.14.50:11434"  # NODE ollama via Tailscale
DEFAULT_MODEL = "llama3.2:3b"
LATEX_RATE_LIMIT_S = 3

DEFAULT_BACKEND = os.environ.get("KESTREL_LLAMA_BACKEND", "node").strip().lower()
BEDROCK_REGION = os.environ.get("KESTREL_BEDROCK_REGION", "us-east-1")
BEDROCK_MODEL = os.environ.get(
    "KESTREL_BEDROCK_MODEL",
    "global.anthropic.claude-haiku-4-5-20251001-v1:0",
)
BEDROCK_MAX_TOKENS = int(os.environ.get("KESTREL_BEDROCK_MAX_TOKENS", "220"))
BEDROCK_TEMPERATURE = float(os.environ.get("KESTREL_BEDROCK_TEMPERATURE", "0"))
BEDROCK_MAX_RETRIES = int(os.environ.get("KESTREL_BEDROCK_MAX_RETRIES", "4"))
BEDROCK_BASE_BACKOFF_S = float(os.environ.get("KESTREL_BEDROCK_BASE_BACKOFF_S", "1.0"))
BEDROCK_RECORD_SLEEP_S = float(os.environ.get("KESTREL_BEDROCK_RECORD_SLEEP_S", "0.5"))
NODE_RECORD_SLEEP_S = float(os.environ.get("KESTREL_NODE_RECORD_SLEEP_S", "2.0"))

# Conservative, env-overridable guardrails. These are safety cutoffs, not billing truth.
BEDROCK_INPUT_USD_PER_M = float(os.environ.get("KESTREL_BEDROCK_INPUT_USD_PER_M", "1.00"))
BEDROCK_OUTPUT_USD_PER_M = float(os.environ.get("KESTREL_BEDROCK_OUTPUT_USD_PER_M", "5.00"))
BEDROCK_MAX_COST_USD = float(os.environ.get("KESTREL_BEDROCK_MAX_COST_USD", "5.00"))
BEDROCK_MAX_TOTAL_TOKENS = int(os.environ.get("KESTREL_BEDROCK_MAX_TOTAL_TOKENS", "5000000"))


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def log(msg):
    line = f"{utc_now()} {msg}"
    print(line, flush=True)
    CONSUME_LOG.parent.mkdir(parents=True, exist_ok=True)
    with CONSUME_LOG.open("a") as f:
        f.write(line + "\n")


def ollama_available(model):
    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            models = [m.get("name", "") for m in data.get("models", [])]
            return any(model in m for m in models)
    except Exception:
        return False


def ollama_generate(model, prompt):
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"num_thread": 2, "num_predict": 150, "num_ctx": 512},
    }).encode()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read()), None
    except urllib.error.URLError as exc:
        return None, str(exc)
    except Exception as exc:
        return None, str(exc)


def _bedrock_extract_text(resp):
    content = resp.get("output", {}).get("message", {}).get("content", [])
    reasoning_present = any(
        isinstance(block, dict) and "reasoningContent" in block
        for block in content
    )
    for block in content:
        if isinstance(block, dict) and "text" in block:
            return block["text"], reasoning_present
    return "", reasoning_present


def _bedrock_estimated_cost(usage):
    input_tokens = int(usage.get("inputTokens") or 0)
    output_tokens = int(usage.get("outputTokens") or 0)
    return (
        (input_tokens / 1_000_000.0) * BEDROCK_INPUT_USD_PER_M
        + (output_tokens / 1_000_000.0) * BEDROCK_OUTPUT_USD_PER_M
    )


def bedrock_generate(model, prompt, budget):
    if boto3 is None:
        return None, "boto3/botocore unavailable"

    client = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
    last_err = None

    for attempt in range(1, BEDROCK_MAX_RETRIES + 1):
        t0 = time.time()
        try:
            resp = client.converse(
                modelId=model,
                messages=[{
                    "role": "user",
                    "content": [{"text": prompt}],
                }],
                inferenceConfig={
                    "maxTokens": BEDROCK_MAX_TOKENS,
                    "temperature": BEDROCK_TEMPERATURE,
                },
            )
            latency_ms = int((time.time() - t0) * 1000)
            text, reasoning_present = _bedrock_extract_text(resp)
            if not text:
                return None, "Bedrock response contained no text block"

            usage = resp.get("usage", {})
            input_tokens = int(usage.get("inputTokens") or 0)
            output_tokens = int(usage.get("outputTokens") or 0)
            total_tokens = int(usage.get("totalTokens") or (input_tokens + output_tokens))
            est_cost = _bedrock_estimated_cost(usage)

            budget["total_tokens"] += total_tokens
            budget["estimated_cost_usd"] += est_cost

            meta = {
                "region": BEDROCK_REGION,
                "model": model,
                "latency_ms": latency_ms,
                "usage": usage,
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "total_tokens": total_tokens,
                "estimated_cost_usd": est_cost,
                "cumulative_tokens": budget["total_tokens"],
                "cumulative_estimated_cost_usd": budget["estimated_cost_usd"],
                "reasoning_content_present": reasoning_present,
                "stop_reason": resp.get("stopReason"),
                "attempt": attempt,
            }

            if (
                budget["total_tokens"] > BEDROCK_MAX_TOTAL_TOKENS
                or budget["estimated_cost_usd"] > BEDROCK_MAX_COST_USD
            ):
                budget["stop_after_record"] = True
                meta["budget_stop_after_record"] = True

            return {"response": text, "_bedrock": meta}, None

        except (ClientError, BotoCoreError, TimeoutError) as exc:
            code = ""
            if hasattr(exc, "response"):
                code = exc.response.get("Error", {}).get("Code", "")
            last_err = f"{type(exc).__name__}:{code}:{exc}"
            retryable = code in {
                "ThrottlingException",
                "TooManyRequestsException",
                "ServiceUnavailableException",
                "InternalServerException",
                "ModelTimeoutException",
            }
            if retryable and attempt < BEDROCK_MAX_RETRIES:
                delay = BEDROCK_BASE_BACKOFF_S * (2 ** (attempt - 1)) + random.uniform(0, 0.25)
                log(f"[bedrock] retry attempt={attempt} code={code} sleep={delay:.2f}s")
                time.sleep(delay)
                continue
            return None, last_err

        except Exception as exc:
            last_err = f"{type(exc).__name__}:{exc}"
            if attempt < BEDROCK_MAX_RETRIES:
                delay = BEDROCK_BASE_BACKOFF_S * (2 ** (attempt - 1)) + random.uniform(0, 0.25)
                log(f"[bedrock] retry attempt={attempt} error={type(exc).__name__} sleep={delay:.2f}s")
                time.sleep(delay)
                continue
            return None, last_err

    return None, last_err or "Bedrock generate failed"


def fetch_latex(arxiv_id):
    """Fetch LaTeX source tarball from arXiv. Best-effort, non-blocking."""
    if not arxiv_id:
        log("[latex_fetch] skip: no arxiv_id")
        return False
    LATEX_DIR.mkdir(parents=True, exist_ok=True)
    safe_id = arxiv_id.replace("/", "_")  # quant-ph/9705052 -> quant-ph_9705052
    dest = LATEX_DIR / f"{safe_id}.tar.gz"
    if dest.exists():
        log(f"[latex_fetch] {arxiv_id} -> already cached")
        return True
    url = f"https://arxiv.org/e-print/{arxiv_id}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "kestrel-pipeline/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        dest.write_bytes(data)
        log(f"[latex_fetch] {arxiv_id} -> stored ({len(data)} bytes)")
        return True
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            log(f"[latex_fetch] {arxiv_id} -> not_found (404)")
        else:
            log(f"[latex_fetch] {arxiv_id} -> error HTTP {exc.code}")
        return False
    except Exception as exc:
        log(f"[latex_fetch] {arxiv_id} -> error {exc}")
        return False


def backfill_latex():
    """Fetch LaTeX for all existing llama_ready papers that don't have a cached tarball."""
    ready_files = sorted(LLAMA_READY_DIR.glob("*.json")) if LLAMA_READY_DIR.exists() else []
    fetched = skipped = no_id = 0
    for path in ready_files:
        artifact = json.loads(path.read_text())
        arxiv_id = artifact.get("arxiv_id")
        if not arxiv_id:
            log(f"[latex_fetch] {path.stem} -> no_arxiv_id")
            no_id += 1
            continue
        safe_id = arxiv_id.replace("/", "_")
        dest = LATEX_DIR / f"{safe_id}.tar.gz"
        if dest.exists():
            log(f"[latex_fetch] {arxiv_id} -> already cached")
            skipped += 1
            continue
        fetch_latex(arxiv_id)
        fetched += 1
        time.sleep(LATEX_RATE_LIMIT_S)
    print(f"[latex_fetch] backfill done: fetched={fetched} skipped={skipped} no_arxiv_id={no_id}")
    return 0


def promote(paper_id, model):
    src = CANDIDATES_DIR / f"{paper_id}.json"
    if not src.exists():
        print(f"[llama_consume] candidate not found: {paper_id}", file=sys.stderr)
        return 1

    artifact = json.loads(src.read_text())

    # TRUTH GATE INVARIANT -- hard fail, never promote ghost papers
    _ev = artifact.get("evidence", {})
    _w3m = _ev.get("w3m_validation", {})
    _w3m_ok = artifact.get("primary_w3m_ok", bool(_w3m.get("match")))
    _evidence_count = artifact.get(
        "evidence_count",
        sum(1 for k in ("semantic_scholar", "openalex", "inspirehep", "springer") if _ev.get(k))
    )

    if artifact.get("corroboration_level") != "CORROBORATED":
        raise RuntimeError(
            "TRUTH GATE VIOLATION: refusing non-CORROBORATED promotion "
            f"level={artifact.get('corroboration_level')!r} "
            f"paper_id={paper_id} title={artifact.get('title', '')!r}"
        )

    if _evidence_count < 2 or not _w3m_ok:
        raise RuntimeError(
            "TRUTH GATE VIOLATION: refusing CORROBORATED promotion "
            f"w3m_ok={_w3m_ok} evidence_count={_evidence_count} "
            f"paper_id={paper_id} title={artifact.get('title', '')!r}"
        )

    LLAMA_READY_DIR.mkdir(parents=True, exist_ok=True)
    dst = LLAMA_READY_DIR / f"{paper_id}.json"
    artifact["promoted_to_llama_ready_at"] = utc_now()
    artifact["promoted"] = True
    dst.write_text(json.dumps(artifact, indent=2) + "\n")
    log(f"[promote] {paper_id} -> llama_ready/")
    fetch_latex(artifact.get("arxiv_id"))
    print(f"[llama_consume] promoted {paper_id} to llama_ready/")
    return 0


def consume(model, backend=DEFAULT_BACKEND, limit=None):
    backend = (backend or DEFAULT_BACKEND).strip().lower()
    if backend not in {"node", "bedrock"}:
        print(f"[llama_consume] invalid backend: {backend}", file=sys.stderr)
        return 2

    if backend == "node":
        if not ollama_available(model):
            print(f"[llama_consume] NODE ollama unreachable at {OLLAMA_URL} or model '{model}' not loaded", file=sys.stderr)
            log(f"[consume] ABORT: NODE ollama unreachable endpoint={OLLAMA_URL} model={model}")
            return 1
    elif boto3 is None:
        print("[llama_consume] boto3/botocore unavailable for Bedrock backend", file=sys.stderr)
        log("[consume] ABORT: boto3/botocore unavailable for Bedrock backend")
        return 1

    ready_files = sorted(LLAMA_READY_DIR.glob("*.json")) if LLAMA_READY_DIR.exists() else []
    if not ready_files:
        print("[llama_consume] llama_ready/ is empty -- nothing to consume")
        return 0

    consumed = 0
    attempted = 0
    budget = {"total_tokens": 0, "estimated_cost_usd": 0.0, "stop_after_record": False}

    for path in ready_files:
        if limit is not None and attempted >= limit:
            log(f"[consume] attempt limit reached attempted={attempted} consumed={consumed} limit={limit}")
            break

        artifact = json.loads(path.read_text())
        if artifact.get("llama_consumed"):
            continue

        if not artifact.get("title", "").strip() or not artifact.get("corpus_record"):
            log(f"[consume] skipped empty record {artifact.get('paper_id', '?')}")
            continue

        content = ""
        if artifact.get("corpus_record"):
            content = artifact["corpus_record"].get("content", "")
        if not content:
            content = artifact.get("title", "")

        if not content:
            log(f"[consume] skip {path.stem}: no content")
            continue

        prompt = (
            f"You are building a quantum computing knowledge base. "
            f"Summarize the key contribution of this paper in 2-3 sentences:\n\n{content[:800]}"
        )

        attempted += 1

        if backend == "bedrock":
            log(f"[consume] sending {path.stem} to bedrock model={model} region={BEDROCK_REGION}")
            result, err = bedrock_generate(model, prompt, budget)
        else:
            log(f"[consume] sending {path.stem} to {model} via {OLLAMA_URL}")
            result, err = ollama_generate(model, prompt)

        if err:
            log(f"[consume] error on {path.stem} backend={backend} model={model}: {err}")
            hard_bedrock_errors = (
                "AccessDeniedException",
                "ResourceNotFoundException",
                "ValidationException",
                "ModelNotReadyException",
            )
            if backend == "bedrock" and any(code in err for code in hard_bedrock_errors):
                log(f"[consume] ABORT hard bedrock error after attempted={attempted} consumed={consumed}: {err}")
                print(f"[llama_consume] ABORT hard bedrock error attempted={attempted} consumed={consumed}", file=sys.stderr)
                return 1
            continue

        consumed_at = utc_now()
        artifact["llama_consumed"] = True
        artifact["llama_consumed_at"] = consumed_at
        artifact["llama_model"] = model
        artifact["llama_backend"] = backend
        artifact["llama_response"] = result.get("response", "")[:500]

        if backend == "bedrock":
            meta = result.get("_bedrock", {})
            artifact["llama_bedrock_usage"] = meta.get("usage", {})
            artifact["llama_bedrock_latency_ms"] = meta.get("latency_ms")
            artifact["llama_bedrock_estimated_cost_usd"] = meta.get("estimated_cost_usd")
            log(
                "[consume] bedrock_meta "
                f"doc={path.stem} latency_ms={meta.get('latency_ms')} "
                f"tokens={meta.get('total_tokens')} "
                f"cumulative_tokens={meta.get('cumulative_tokens')} "
                f"estimated_cost_usd={meta.get('estimated_cost_usd')} "
                f"cumulative_estimated_cost_usd={meta.get('cumulative_estimated_cost_usd')} "
                f"reasoning={meta.get('reasoning_content_present')}"
            )

        path.write_text(json.dumps(artifact, indent=2) + "\n")
        OFFLOAD_LIST.parent.mkdir(parents=True, exist_ok=True)
        with OFFLOAD_LIST.open("a") as f:
            f.write(json.dumps({
                "doc_id": path.stem,
                "arxiv_id": artifact.get("arxiv_id", ""),
                "title": artifact.get("title", ""),
                "truth_gate": artifact.get("corroboration_level", "CORROBORATED"),
                "promoted_to_llama_ready": True,
                "promoted_at": artifact.get("promoted_to_llama_ready_at", ""),
                "llama_consumed_at": consumed_at,
                "consumed": True,
                "llama_backend": backend,
            }, ensure_ascii=False) + "\n")

        consumed += 1
        log(f"[consume] done {path.stem} backend={backend}")

        if budget.get("stop_after_record"):
            log(
                "[consume] BEDROCK BUDGET STOP "
                f"tokens={budget['total_tokens']} "
                f"estimated_cost_usd={budget['estimated_cost_usd']}"
            )
            break

        time.sleep(BEDROCK_RECORD_SLEEP_S if backend == "bedrock" else NODE_RECORD_SLEEP_S)

    print(f"[llama_consume] attempted={attempted} consumed={consumed} backend={backend}")
    if backend == "bedrock":
        print(json.dumps({
            "bedrock_total_tokens": budget["total_tokens"],
            "bedrock_estimated_cost_usd": budget["estimated_cost_usd"],
        }, indent=2))
    return 0


def status(backend=DEFAULT_BACKEND):
    backend = (backend or DEFAULT_BACKEND).strip().lower()
    candidates = list(CANDIDATES_DIR.glob("*.json")) if CANDIDATES_DIR.exists() else []
    ready = list(LLAMA_READY_DIR.glob("*.json")) if LLAMA_READY_DIR.exists() else []
    consumed = [f for f in ready if json.loads(f.read_text()).get("llama_consumed")]

    out = {
        "backend": backend,
        "candidates": len(candidates),
        "llama_ready": len(ready),
        "llama_consumed": len(consumed),
        "offload_list_records": sum(1 for _ in open(OFFLOAD_LIST)) if OFFLOAD_LIST.exists() else 0,
    }
    if backend == "node":
        out["ollama_up"] = ollama_available(DEFAULT_MODEL)
        out["ollama_url"] = OLLAMA_URL
        out["node_model"] = DEFAULT_MODEL
    elif backend == "bedrock":
        out["bedrock_region"] = BEDROCK_REGION
        out["bedrock_model"] = BEDROCK_MODEL
        out["bedrock_max_cost_usd"] = BEDROCK_MAX_COST_USD
        out["bedrock_max_total_tokens"] = BEDROCK_MAX_TOTAL_TOKENS

    print(json.dumps(out, indent=2))
    return 0


def main():
    parser = argparse.ArgumentParser(description="NODE LLaMA consumer")
    parser.add_argument("--promote", metavar="PAPER_ID", help="Promote candidate to llama_ready")
    parser.add_argument("--consume", action="store_true", help="Send llama_ready records to selected backend")
    parser.add_argument("--status", action="store_true", help="Show pipeline state")
    parser.add_argument("--backfill-latex", action="store_true", help="Fetch LaTeX tarballs for all existing llama_ready papers")
    parser.add_argument("--backend", choices=["node", "bedrock"], default=DEFAULT_BACKEND, help=f"Consume backend (default: {DEFAULT_BACKEND})")
    parser.add_argument("--model", default=None, help="Ollama model for node backend; optional override for bedrock backend")
    parser.add_argument("--bedrock-model", default=BEDROCK_MODEL, help=f"Bedrock model id (default: {BEDROCK_MODEL})")
    parser.add_argument("--limit", type=int, default=None, help="Maximum number of records to consume in this run")
    args = parser.parse_args()

    model = args.model or (args.bedrock_model if args.backend == "bedrock" else DEFAULT_MODEL)

    if args.status:
        return status(args.backend)
    if args.promote:
        return promote(args.promote, model)
    if args.consume:
        return consume(model, backend=args.backend, limit=args.limit)
    if args.backfill_latex:
        return backfill_latex()
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
