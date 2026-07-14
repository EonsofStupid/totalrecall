# TotalRecall — Plan of Action & Milestones (POA&M)

**What TotalRecall is:** a complete, embedded, tokio-native Advanced RAG engine built for the Clyffy/DevPulse
intelligence stack. The engine composes a vector recall core (`EdgeShard`), a BM25 hybrid layer (`bm25_embed`),
a crash-safe WAL, and an in-process optimizer into a single handle that the host embeds directly — no server,
no network hop. The companion graph/KVS layer is **Connectome** (separate repo).

**Status legend:** ✅ done · 🟡 in progress · ⬜ not started · 🔵 planned

---

## Milestone summary

| ID | Objective | Definition of Done | Status |
|----|-----------|-------------------|--------|
| **TR-0** | Embedded recall core | `EdgeShard` stable: search / query / update / facet / snapshot / optimize — all ops tested | ✅ |
| **TR-1** | `trecall` facade crate | `use trecall::{TotalRecall, …}` compiles; versioned public API contract | ⬜ |
| **TR-2** | Connectome fusion | Connectome graph routes → EdgeShard ANN; map + treasure end-to-end green | ⬜ |
| **TR-3** | Preflight training pipeline | Index warm-up, capacity profiling, recall benchmarks pass on target hardware | ⬜ |
| **TR-4** | RRD — Reason-Ready Daemon | In-process daemon; JIT context assembly; first token latency target met | 🔵 |
| **TR-5** | A2A mesh + MCP | Remote A2A channel; peer ingestion; MCP session routing; streaming recall | 🔵 |
| **TR-6** | Qortex pipeline | Reranker + embedder fused in the recall hot path; end-to-end latency budget | 🔵 |
| **TR-7** | Full-stack demo | Clyffy user hits enter → dynamic reasoning fires → result in a single RTT | 🔵 |

---

## Objectives in detail

### TR-0 — Embedded recall core ✅

The `lib/edge` crate exposes `EdgeShard` — the single in-process handle:

- **Ops:** `search` · `query` (RRF / score_fusion / MMR / formula re-score) · `update` · `retrieve` · `scroll`
  · `count` · `facet` · `optimize` (indexing / merge / vacuum / config-mismatch) · `snapshot`
- **Hybrid:** `bm25_embed` embeds text to `SparseVector` (murmur3 term hashing, configurable stemmer +
  stopwords + ASCII folding); fuse with dense via RRF or score_fusion
- **Indices:** HNSW (configurable `m`, `ef_construction`), flat (exact), scalar int8 / product / binary
  quantization, on-disk + mmap, payload indices (keyword / text / int / float / geo / datetime / UUID)
- **WAL:** serde-backed crash-safe write-ahead log; replay on load
- **Python:** PyO3 bindings in `lib/edge/python` expose full surface to Python runtimes

**Evidence:** `cargo test -p edge` green; `cargo test -p segment --lib` green.

### TR-1 — `trecall` facade crate ⬜

**Objective:** consumers depend on `trecall`, not on `edge`/`segment` internals.

- [ ] **M1.1** — add a thin `trecall` crate that re-exports the `edge` surface + a stable `TotalRecall`
  handle: `open(path, config)` / `collection(name)` / `upsert(points)` / `search(query)` / `close()`.
- [ ] **M1.2** — server bins (`actix`, consensus) feature-gated behind an off-by-default `server` feature
  so `cargo build -p trecall` is the embedded-only build.
- [ ] **M1.3** — version the public API contract; document in `docs/EMBEDDING.md`.

**DoD:** `use trecall::{TotalRecall, …}` compiles and drives an in-process instance; `cargo build -p trecall`
produces no server code.

### TR-2 — Connectome fusion ⬜

**Objective:** wire TotalRecall's recall path behind Connectome's graph/KVS routing layer.

- Connectome owns the **map** (graph, relationships, breadcrumbs, document metadata).
- TotalRecall owns the **treasure** (vectors, recall, re-score).
- The fusion pattern: Connectome resolves the recall route → passes a query to TotalRecall's `EdgeShard` →
  ANN result enriched with graph context before returning to the caller.

Steps:
- [ ] **M2.1** — `clyffy-storage/src/adapters/trecall/` implements `VectorStore` over the `trecall` facade
  (feature `trecall`).
- [ ] **M2.2** — Connectome KVS stores document payloads; TotalRecall stores the corresponding vectors.
  Payload round-trip stays consistent.
- [ ] **M2.3** — telemetry: `gen_ai.*` / `devpulse.*` recall spans.

**DoD:** map → treasure round-trip on operator data; recall ≥ target on a golden set.

### TR-3 — Preflight training pipeline ⬜

**Objective:** before Clyffy deploys at a remote site, preflight runs a warm-up + capacity check.

- Index warm-up: ingest a representative corpus slice, trigger the full optimizer pipeline.
- Capacity profiling: measure RAM, disk, and recall at each quantization tier.
- Recall benchmark: verify recall ≥ 0.95 binary+rescore on the golden set.
- Output: a `ResourceProfile` that Clyffy uses to configure `EdgeShard` on deploy.

**DoD:** preflight binary exits 0 and emits a profile; Clyffy reads it on startup.

### TR-4 — RRD (Reason-Ready Daemon) 🔵

**Objective:** keep TotalRecall hot in-process so the first token after "enter" costs zero cold-start time.

- The RRD is an always-running tokio task that:
  - Pre-warms HNSW ef_search paths for the current project's typical query distribution.
  - Assembles the JIT context window from prior recall sessions (Connectome breadcrumbs + vector
    neighbourhood).
  - Holds a live `EdgeShard` handle; no open/close overhead on each query.
- On "enter": RRD receives the query, returns the assembled context in sub-millisecond latency.

**DoD:** measured first-token latency ≤ budget on target hardware.

### TR-5 — A2A mesh + MCP 🔵

**Objective:** TotalRecall participates in a peer network; remote agents can delegate recall.

- **A2A (Agent-to-Agent):** establish an authenticated channel between Clyffy instances; delegate vector
  recall to a remote TotalRecall when the local shard lacks coverage.
- **MCP (Multi-Channel Protocol):** session-aware routing so a single logical query fans out to the right
  shard(s) across the mesh.
- Ingestion via the A2A channel: a remote agent pushes documents; the local shard ingests them, runs
  preflight, and confirms coverage.

**DoD:** remote channel established; ingestion perf exceeds stock; recall over mesh ≥ local baseline.

### TR-6 — Qortex pipeline 🔵

**Objective:** fuse reranker and embedder into the recall hot path without leaving the process.

- Qortex sits between `EdgeShard.query()` and the caller: it re-embeds the query if the model has been
  updated, re-ranks the ANN top-k, and returns the final ranked list.
- All in-process, same tokio runtime — zero extra network hops.

**DoD:** end-to-end latency budget met with reranker active; recall ≥ target.

### TR-7 — Full-stack demo 🔵

**Objective:** close the loop: user hits enter in Clyffy → dynamic reasoning fires → result returned.

The complete chain:
```
User enter
  → RRD assembles JIT context (TR-4)
  → Connectome map resolves recall route (TR-2)
  → TotalRecall EdgeShard executes ANN + BM25 hybrid + Qortex rerank (TR-0, TR-6)
  → A2A peers contribute if needed (TR-5)
  → Result back to Clyffy in a single RTT
```

**DoD:** demo runs on target hardware; latency ≤ budget; recall ≥ target; no crashes.

---

## Guardrails

- **Embedded first.** The server binary is opt-in; the default build is the recall core.
- **No faked green.** A milestone is done only when evidence exists on the target hardware.
- **Connectome is separate.** TotalRecall does not own the graph layer; the fusion seam is explicit.
- **Stable public API.** Once `trecall` v1.0 ships, breaking changes are a major version bump.
