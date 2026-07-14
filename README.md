# TotalRecall — Advanced RAG Engine

`trecall` — Total Recall is a complete, embedded, tokio-native Advanced RAG engine for Clyffy/DevPulse. It is
**not** a wrapper or a simple fork — the vector engine foundations were stripped down and rebuilt as a
purpose-built recall core. Companion KVS: [Connectome](https://github.com/EonsofStupid/connectome) (replaces SurrealDB;
provides the graph/relationship layer that feeds the RAG pipeline).

> **Attribution.** The vector-engine layer of TotalRecall is derived from
> [Qdrant](https://github.com/qdrant/qdrant) v1.18.2 (Apache-2.0). TotalRecall is **not affiliated with,
> endorsed by, or supported by** the Qdrant project or Qdrant Solutions GmbH. "Qdrant" is a trademark of its
> owners used here only for attribution. Full attribution: [NOTICE](NOTICE).

## What TotalRecall Is

TotalRecall is the **recall layer** of the Clyffy intelligence stack — a production RAG engine, not a demo:

- **Vector engine** — dense + sparse (BM25 hybrid) ANN, quantization tiers (int8 / binary / PQ), on-disk + mmap
- **Connectome integration** — Connectome (the graph/KVS host) resolves routes; TotalRecall executes ANN recall
- **Embeddable first** — runs entirely in-process via `lib/edge`; no actix / consensus / distributed layer required
- **Hybrid retrieval** — `bm25_embed` fused with dense rescore; per-project collections; capacity profiles

## Engine architecture

| Layer | Crate | Role |
|-------|-------|------|
| Recall surface | `lib/edge` | stable in-process API (search / query / retrieve / facet / snapshots / optimize) |
| Vector segments | `lib/segment` | HNSW / flat / quantized indices, payload storage, WAL |
| Sparse / BM25 | `lib/sparse`, `lib/bm25` | inverted index + BM25 scoring |
| Shard / WAL | `lib/shard`, `lib/wal` | write-ahead log, shard management |
| Facade | `trecall` bin (alias for engine entry-point; `cargo run --bin trecall`) / future standalone crate | consumer entry-point |

The full roadmap (POA&M) is at [docs/POAM.md](docs/POAM.md).

## Vector-engine provenance

| | |
|---|---|
| Upstream base | `qdrant/qdrant` **v1.18.2** (commit `44ad62f8cd69642be5afa6441612525e24a0d063`) |
| Track model | **grafted** — real shared ancestry; new base releases merge in via `git merge` (see [docs/UPSTREAM_ALIGNMENT.md](docs/UPSTREAM_ALIGNMENT.md)) |
| Baseline tag | `qdrant-v1.18.2-baseline` |
| License | Apache-2.0 (see [LICENSE](LICENSE); attribution in [NOTICE](NOTICE)) |

The original upstream README is preserved at [docs/UPSTREAM_README.md](docs/UPSTREAM_README.md).

## Local deltas vs upstream v1.18.2

- `rust-toolchain.toml` added — pinned **stable 1.96** (base needs
  `cfg_select` / `vec_into_raw_parts` / `ptr_as_ref_unchecked`; stable so Clyffy
  can consume TotalRecall on the same toolchain). Bump when bumping the base.
- `geo` pinned to **0.32** in `lib/segment` to compile alongside
  `connectome-core` with a single `geo` version (no `[patch]` hack).
  Verified: `cargo test -p segment --lib` — 684 passed / 0 failed.
- LFS test artifact `tests/e2e_tests/test_data/storage.tar.xz` removed
  (and its `.gitattributes` entries) to keep the repo clean of LFS.
- `parking_lot` workspace dep drops `deadlock_detection` (mutually exclusive with `send_guard`, which the
  in-process embedding host pulls). Debug-only; still reachable via the `service_debug` feature.

## Syncing with upstream

`main` shares real ancestry with `qdrant/qdrant` (base `v1.18.2`), so a new release is a **`git merge`**, not a
hand-applied diff:

```bash
git fetch upstream --tags
git switch -c sync/qdrant-vNEW main && git merge vNEW   # 3-way; conflicts only where our deltas overlap
# resolve per the delta table, re-verify, then:
git switch main && git merge --ff-only sync/qdrant-vNEW
git tag qdrant-vNEW-baseline vNEW && git tag vNEW-trecall.0 main && git push origin main --tags
```

Full runbook + the SSOT list of local deltas to re-verify: **[docs/UPSTREAM_ALIGNMENT.md](docs/UPSTREAM_ALIGNMENT.md)**.
The `qdrant-v*-baseline` tag marks the upstream release `main` is merged up to — check it before assuming the fork is current.
