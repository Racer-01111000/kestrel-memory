#!/usr/bin/env bash
# tests/test_sources.sh — unit tests for each witness/discovery function
# Run manually before any production deployment.
# Usage: bash tests/test_sources.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/sources.sh"

PASS=0
FAIL=0

assert_nonempty() {
  local name="$1" result="$2"
  if [ -n "$result" ] && [ "$result" != "[]" ] && [ "$result" != "null" ]; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name — empty or null result"
    FAIL=$((FAIL + 1))
  fi
}

assert_json_has_items() {
  local name="$1" json="$2"
  local count
  count=$(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "  [PASS] $name ($count hit(s))"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name — 0 hits"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Discovery sources (non-voting) ==="

echo "--- OpenAlex: 'surface code quantum error correction' ---"
result=$(query_openalex "surface code quantum error correction")
assert_nonempty "query_openalex" "$result"
sleep 2

echo "--- Semantic Scholar: 'quantum error correction' ---"
result=$(query_semantic_scholar "quantum error correction")
# S2 may 429 — treat rate-limit as a skip, not a failure
if echo "$result" | grep -qi "rate\|429" 2>/dev/null || [ -z "$result" ]; then
  echo "  [SKIP] query_semantic_scholar — rate limited or unreachable"
else
  assert_nonempty "query_semantic_scholar" "$result"
fi
sleep 3

echo ""
echo "=== Witness sources (voting) ==="

echo "--- arXiv API: 'surface code threshold theorem' ---"
result=$(witness_arxiv "surface code threshold theorem")
assert_json_has_items "witness_arxiv" "$result"
sleep 4

echo "--- Crossref: 'quantum error correction' ---"
result=$(witness_crossref "quantum error correction")
assert_json_has_items "witness_crossref" "$result"
sleep 2

echo "--- INSPIRE-HEP: 'quantum field theory renormalization' ---"
result=$(witness_inspire "quantum field theory renormalization")
if [ "$result" = "[]" ]; then
  echo "  [SKIP] witness_inspire — unreachable from this network"
else
  assert_json_has_items "witness_inspire" "$result"
fi
sleep 2

echo "--- NIST/CSRC: 'post-quantum cryptography' ---"
result=$(witness_nist "post-quantum cryptography")
assert_json_has_items "witness_nist" "$result"

echo ""
echo "=== match_corroboration() ==="

long_text="Quantum error correction is a technique to protect quantum information from errors due to decoherence and other noise. Surface codes are a prominent class of quantum error correcting codes defined on a two-dimensional lattice of physical qubits. The threshold theorem states that if the physical error rate is below a certain threshold value, arbitrarily long quantum computations can be performed reliably using a polynomial overhead of physical qubits. Recent experiments have demonstrated surface code operation at or near the fault-tolerance threshold on superconducting qubit arrays, confirming long-standing theoretical predictions and representing a major milestone on the path toward practical fault-tolerant quantum computing systems."
short_text="short"

match_corroboration "surface code threshold quantum" "$long_text" \
  && echo "  [PASS] match_corroboration long text" && PASS=$((PASS+1)) \
  || { echo "  [FAIL] match_corroboration long text"; FAIL=$((FAIL+1)); }

match_corroboration "surface code threshold" "$short_text" \
  && { echo "  [FAIL] match_corroboration short text (should have failed)"; FAIL=$((FAIL+1)); } \
  || { echo "  [PASS] match_corroboration short text correctly rejected"; PASS=$((PASS+1)); }

echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
[ $FAIL -eq 0 ] && echo "  STATUS: ALL PASS" && exit 0 || { echo "  STATUS: FAILURES PRESENT"; exit 1; }
