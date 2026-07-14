# TotalRecall — Developer Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Rust | stable ≥ 1.96 | pinned via `rust-toolchain.toml`; install with `rustup` |
| `protoc` | any recent | required to compile gRPC stubs in `lib/api` |
| Python 3.9+ | optional | for `lib/edge/python` bindings (maturin) |

Install the pinned toolchain:
```bash
rustup show   # installs the toolchain from rust-toolchain.toml automatically
```

## Building

```bash
# Embedded recall core only (recommended for development)
cargo build -p edge

# Full server binary
cargo build --bin trecall

# Release build
cargo build --release --bin trecall
```

## Running tests

```bash
# Edge unit tests
cargo test -p edge

# Segment unit tests (vector indexing, quantization, payload)
cargo test -p segment --lib

# BM25 unit tests
cargo test -p bm25

# Full workspace unit tests
cargo test --lib
```

Integration and consensus tests require a running instance and are in `tests/`.

## Python bindings

```bash
cd lib/edge/python
python -m venv .venv && source .venv/bin/activate
pip install maturin
maturin develop --no-default-features
python examples/demo.py
```

## Docker

Build the image:
```bash
docker build . --tag=trecall:latest
```

Run:
```bash
docker run -p 6333:6333 \
    -v $(pwd)/data:/trecall/storage \
    -v $(pwd)/snapshots:/trecall/snapshots \
    trecall:latest
```

## API changes

If you change the REST or gRPC API:

1. Update the OpenAPI schema: `cargo run --bin schema_generator --features service_debug > openapi/openapi.json`
2. Regenerate OpenAPI models: `tools/generate_openapi_models.sh`
3. Update the schema in `tools/schema2openapi/` if the JSON Schema changes.

## Profiling

TotalRecall supports `tracing` with Tracy and `tokio-console`:

```bash
# Tracy
cargo run --bin trecall --features=tracing-tracy

# tokio-console
cargo run --bin trecall --features=console
```

For flamegraph profiling on Linux:
```bash
cargo build --profile perf --bin trecall
# run under perf/flamegraph as usual
```

## Configuration

The default config is `config/config.yaml`. Override per environment:
- `config/development.yaml` — local dev overrides
- `config/production.yaml` — production overrides

All config keys and defaults are documented inline in `config/config.yaml`.
