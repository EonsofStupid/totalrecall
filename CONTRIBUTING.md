# Contributing to TotalRecall

TotalRecall is the recall engine for the Clyffy/DevPulse intelligence stack. Contributions are welcome.

## Reporting issues

Open a GitHub issue at [EonsofStupid/totalrecall](https://github.com/EonsofStupid/totalrecall/issues).
Include: what you did, what you expected, what happened, and your environment (OS, Rust toolchain, hardware).

## Pull requests

1. Fork the repo, create a branch from `main`.
2. Make your change. Keep commits focused; one logical change per PR.
3. Run the affected test suites before opening the PR (see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)).
4. Describe *what* changed and *why* in the PR description.

## Code style

- `rustfmt` with the repo's `rustfmt.toml`.
- `clippy` with `clippy.toml` — the workspace lint table in `Cargo.toml` lists active lints.
- No `#[allow(…)]` without a comment explaining why it is safe.

## Scope

This repo is the **vector recall core**. Contributions touching:

- `lib/edge` — the embedded `EdgeShard` API
- `lib/bm25` / `lib/sparse` — hybrid retrieval
- `lib/segment` / `lib/shard` / `lib/wal` — the storage engine
- `lib/gridstore` / `lib/trififo` — TotalRecall-native primitives

…are in scope. The companion graph/KVS layer lives in [Connectome](https://github.com/EonsofStupid/connectome).
