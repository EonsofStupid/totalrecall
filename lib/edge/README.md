# `edge` — TotalRecall embedded recall surface

The `edge` crate is the stable in-process API for TotalRecall. It composes
`segment + shard + sparse + bm25 + wal` into a single `EdgeShard` handle that the host
(Clyffy, a Python runtime, or any Rust binary) embeds directly.

No actix, no consensus, no distributed layer — just recall.

## Quick start

```rust
use edge::{EdgeShard, EdgeConfig, EdgeVectorParams, Distance};

let config = EdgeConfig::builder()
    .add_vector("dense", EdgeVectorParams::new(1536, Distance::Cosine))
    .build();

let shard = EdgeShard::new(&path, config)?;

// upsert
shard.update(upsert_points)?;

// query (RRF / score_fusion / MMR / formula re-score)
let hits = shard.query(request)?;

// BM25 hybrid
use edge::bm25_embed::{EdgeBm25, EdgeBm25Config};
let bm25 = EdgeBm25::new(EdgeBm25Config::default())?;
let sparse = bm25.embed_query("context window assembly");
```

## Operations

| Method | Description |
|--------|-------------|
| `new` / `load` | create or load a shard |
| `update` | upsert / delete points and payloads |
| `search` | single-query ANN (deprecated; use `query`) |
| `query` | full query engine: prefetch, fusion, re-score, MMR |
| `retrieve` | fetch points by ID |
| `scroll` | ordered paginated scan |
| `count` | count matching points |
| `facet` | payload value faceting |
| `optimize` | run indexing / merge / vacuum optimizers |
| `snapshot` | create, unpack, or recover from a snapshot |

## Python bindings

See `lib/edge/python/` for the PyO3 surface.

## Building as a standalone crate

```bash
cargo build -p edge
cargo test -p edge
```
