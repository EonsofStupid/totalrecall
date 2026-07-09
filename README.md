# TotalRecall

`trecall` — embedded, tokio-native vector memory core for Clyffy. Private fork of
[Qdrant](https://github.com/qdrant/qdrant), maintained as a clean single-branch
baseline that tracks upstream releases while being converted from a standalone
server into an embeddable engine fused with the SurrealDB host.

## Provenance

| | |
|---|---|
| Upstream | `qdrant/qdrant` **v1.18.2** (commit `44ad62f8cd69642be5afa6441612525e24a0d063`) |
| Fork model | **grafted** onto upstream `v1.18.2` — real shared ancestry; new Qdrant releases merge in (see [docs/UPSTREAM_ALIGNMENT.md](docs/UPSTREAM_ALIGNMENT.md)) |
| Baseline tag | `qdrant-v1.18.2-baseline` (= upstream `v1.18.2`) |
| License | Apache-2.0 (see [LICENSE](LICENSE); attribution in [NOTICE](NOTICE)) |

The stock Qdrant README is preserved at [docs/UPSTREAM_README.md](docs/UPSTREAM_README.md).

## Embeddable surface & roadmap

The embeddable engine (not the server) is the product. **`lib/edge`** is that surface: it composes
`segment + shard + sparse + bm25 + wal` into an in-process engine (search / query / retrieve / facet /
hybrid `bm25_embed` / snapshots / optimize) with **no** actix / consensus / distributed layer — this is what
DevPulse/Clyffy embeds. The server bins are a legacy of the upstream fork and will be feature-gated off.

The plan to get from "clean fork" → "embedded TotalRecall fused with the SurrealDB host" is tracked as a POA&M with
milestones: [docs/POAM.md](docs/POAM.md). Identity is TotalRecall (`trecall`); internals stay pristine Qdrant so
upstream syncs stay diff-based (below).

## Local deltas vs upstream v1.18.2

- `rust-toolchain.toml` added — pinned **stable 1.96** (Qdrant v1.18.2 needs
  `cfg_select` / `vec_into_raw_parts` / `ptr_as_ref_unchecked`; stable so Clyffy
  can consume TotalRecall on the same toolchain). Bump when bumping Qdrant.
- `geo` pinned to **0.32** in `lib/segment` to compile alongside
  `surrealdb-core` with a single `geo` version (no `[patch]` hack).
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
