# kestrel-memory/runtime/lib

Source functions for the verify_claims pipeline.

## Source tiers

### Discovery (non-voting)

Used to expand a query into candidate papers. Their confirmation does NOT
increment the corroboration count. Rationale: OpenAlex and Semantic Scholar
are aggregators that index arXiv, Crossref, etc. A hit in OpenAlex that
traces back to an arXiv paper is the same witness as the arXiv hit — counting
both would be double-counting one source.

| Function | API |
|---|---|
| `query_openalex()` | api.openalex.org |
| `query_semantic_scholar()` | api.semanticscholar.org |

### Witness (voting)

Independent editorial or submission paths. Each successful hit that passes
`match_corroboration()` increments the corroboration count.

| Function | API | Notes |
|---|---|---|
| `witness_arxiv()` | export.arxiv.org/api | Sleep 3s between calls |
| `witness_crossref()` | api.crossref.org | Polite User-Agent with mailto |
| `witness_inspire()` | inspirehep.net/api | Physics-specific |
| `witness_nist()` | csrc.nist.gov | Only source still using w3m |

## Promotion rules

- `claim → reinforced_claim`: ≥1 distinct witness source with ≥500 chars and ≥3 content word hits
- `reinforced_claim → fact_candidate`: ≥2 DISTINCT witness source names in `verification_sources`
- Same-run double-promotion is disallowed: Pass 2 skips items whose `last_verified_at` equals the current run timestamp

## Adding a new source

1. Add a `witness_<name>()` function to `sources.sh` following the signature:
   - Arg: `$1` = query string
   - Stdout: JSON array of `{source, url, text}` objects
   - Exit 0 on success, nonzero on network/parse failure
2. Add a test case to `tests/test_sources.sh`
3. Wire it into the witness loop in `verify_claims.sh`
4. Update this README
