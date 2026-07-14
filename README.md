# TotalRecall

**Advanced Retrieval-Augmented Generation engine.** TotalRecall is a complete, embedded, tokio-native RAG engine
built for the Clyffy/DevPulse intelligence stack. It runs entirely in-process — no external server, no network
hop — and exposes a single stable handle (`EdgeShard`) through which the host calls search, query, upsert,
facet, snapshot, and optimize.

```
Connectome (graph / KVS routing)
         │
         ▼
   TotalRecall EdgeShard
   ├── dense ANN    (HNSW, quantized: scalar / product / binary)
   ├── sparse ANN   (inverted index + IDF)
   ├── BM25 hybrid  (bm25_embed → SparseVector, fused via RRF / score_fusion)
   ├── payload index (keyword / text / int / float / geo / datetime)
   ├── re-score     (formula engine, MMR, decay)
   ├── WAL          (crash-safe, serde-backed)
   └── optimizer    (indexing / merge / vacuum / config-mismatch, blocking or async)
```

## Core API (`lib/edge`)

`EdgeShard` is the in-process recall unit. Create one, feed it vectors and payloads, recall:

```rust
use edge::{EdgeShard, EdgeConfig, EdgeVectorParams, Distance};

let config = EdgeConfig::builder()
    .add_vector("dense", EdgeVectorParams::new(1536, Distance::Cosine))
    .build();

let shard = EdgeShard::new(&path, config)?;
shard.update(upsert_points)?;
let hits = shard.query(request)?;   // RRF, score fusion, formula re-score, MMR
```

Full surface: `search` · `query` · `retrieve` · `scroll` · `count` · `facet` · `update` · `optimize` · `snapshot`

## Hybrid retrieval (`bm25_embed`)

BM25 sparse embeddings are first-class. Build an `EdgeBm25`, embed queries and documents to `SparseVector`,
store the sparse vectors in a named sparse vector field, and fuse dense + sparse results via RRF:

```rust
use edge::bm25_embed::{EdgeBm25, EdgeBm25Config};

let bm25 = EdgeBm25::new(EdgeBm25Config::default())?;
let sparse_query = bm25.embed_query("dynamic reasoning context window");
// upsert sparse_query alongside dense embedding, then query with hybrid fusion
```

## Architecture

| Crate | Role |
|-------|------|
| `lib/edge` | Embedded recall surface — `EdgeShard` handle, all recall ops |
| `lib/segment` | HNSW / flat / quantized indices, payload storage, WAL integration, mmap |
| `lib/bm25` | Standalone BM25 — compute-only, murmur3 term hashing, `SparseEmbedding` |
| `lib/sparse` | Sparse vector type + IDF modifier |
| `lib/wal` | Serde-backed crash-safe write-ahead log |
| `lib/shard` | Query planning: RRF, score fusion, MMR, formula engine, scroll |
| `lib/collection` | Collection + shard management (server / distributed mode) |
| `lib/gridstore` | Purpose-built KV grid storage (TotalRecall-native) |
| `lib/trififo` | Tri-state FIFO concurrency primitive (TotalRecall-native) |
| `lib/quantization` | Scalar int8 / product / binary quantization |
| `lib/posting_list` | Inverted posting list for sparse/FTS indices |
| `lib/gpu` | GPU acceleration (Vulkan / CUDA optional) |
| `lib/api` | REST + gRPC API types (server surface) |

## Roadmap

Full POA&M: [docs/POAM.md](docs/POAM.md)

Milestones in brief:

| ID | Goal |
|----|------|
| **TR-0** | Embedded recall core stable (`EdgeShard` + BM25 hybrid + WAL) |
| **TR-1** | `trecall` facade crate — stable public API, versioned contract |
| **TR-2** | Connectome fusion — graph/KVS routing feeds EdgeShard ANN |
| **TR-3** | Preflight training pipeline — index warm-up, capacity profiling, recall benchmarks |
| **TR-4** | RRD (Reason-Ready Daemon) — always-hot in-process daemon, JIT context assembly |
| **TR-5** | A2A mesh + MCP — remote channel establishment, peer ingestion, streaming recall |
| **TR-6** | Qortex integration — reranker + embedder pipeline fused in the recall hot path |
| **TR-7** | Full-stack demo — Clyffy hits enter; dynamic reasoning fires in a single RTT |

## Build

Requires: Rust stable 1.96+, `protoc` (for gRPC stubs).

```bash
cargo build -p edge                  # embedded core only
cargo build --bin trecall            # full server binary
cargo test -p edge                   # edge unit tests
cargo test -p segment --lib          # segment unit tests
```

## Python bindings (`lib/edge/python`)

PyO3 bindings exposing `EdgeShard` and `EdgeBm25` to Python:

```bash
cd lib/edge/python
maturin develop --no-default-features
python examples/demo.py
```

## License

Apache-2.0 — see [LICENSE](LICENSE). Attribution: [NOTICE](NOTICE).
