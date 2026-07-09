# Upstream alignment — tracking Qdrant cleanly

TotalRecall is a **grafted fork** of [Qdrant](https://github.com/qdrant/qdrant): `main` shares real git
ancestry with upstream (base = `v1.18.2`, commit `44ad62f8cd69642be5afa6441612525e24a0d063`), and our local
changes ride on top. New Qdrant releases are pulled with a normal **`git merge`** — not a hand-applied diff.

Internal Qdrant crate names stay **pristine** (`segment`, `collection`, `storage`, `sparse`, `quantization`,
`wal`, …). Only the identity layer (README, this doc, the `trecall` bin alias) is ours. That discipline is what
keeps every upstream merge small.

## The local deltas (SSOT — re-verify each after a sync)

These are the ONLY functional changes vs stock Qdrant. Each touches a file upstream may also change, so each is a
potential merge-conflict site — check them after every merge.

| # | Delta | File(s) | Why | Re-verify |
|---|-------|---------|-----|-----------|
| 1 | Pin toolchain **stable 1.96** | `rust-toolchain.toml` | Qdrant needs `cfg_select` / `vec_into_raw_parts` / `ptr_as_ref_unchecked` (stabilized 1.96); stable (not nightly) so the embedding host builds on one toolchain | `cargo +1.96 build`; **bump if a newer Qdrant needs a newer stable** |
| 2 | Pin **`geo` 0.32** | `lib/segment/Cargo.toml` | compile alongside `surrealdb-core` with a single `geo` version (no `[patch]`) | `cargo tree -i geo` shows one version; `cargo test -p segment --lib` |
| 3 | Remove LFS test artifact | `tests/e2e_tests/test_data/storage.tar.xz` (+ its `.gitattributes` entries) | keep the repo free of Git-LFS | `git lfs ls-files` empty; no `.gitattributes` LFS lines |
| 4 | Drop `parking_lot` **`deadlock_detection`** | `Cargo.toml` (`[workspace.dependencies] parking_lot`) | mutually exclusive with `send_guard`, which the in-process embedding host pulls; debug-only, still reachable via the `service_debug` feature | feature list is `["arc_lock", "serde"]`; `service_debug` still compiles |

Identity/branding changes (`README.md`, `docs/POAM.md`, `docs/UPSTREAM_README.md`, the `trecall` `[[bin]]` alias,
this file) are ours permanently and rarely conflict — they live in files upstream doesn't touch.

### Removed upstream files (re-remove on merge)

For fork hygiene / public readiness we deleted Qdrant's project-identity files. Upstream will keep changing some
of them, so a `git merge vNEW` may surface **modify/delete** conflicts — resolve by re-removing:

```bash
git rm -r .github/workflows .github/actions .github/ISSUE_TEMPLATE \
         .github/PULL_REQUEST_TEMPLATE.md .github/review-rules.md \
         .github/codecov.yml .github/dependabot.yml \
         docs/CODE_OF_CONDUCT.md docs/logo.svg docs/logo-dark.svg docs/logo-light.svg
```

`CONTRIBUTING.md` is **replaced** (not deleted) with a fork note — on conflict, keep ours. GitHub Actions is also
disabled at the repo level as a belt-and-suspenders (so upstream CI can never run even if a workflow returns).

## Syncing to a new Qdrant release

```bash
git fetch upstream --tags

# merge the new release into a sync branch (3-way against our v1.18.2 base)
git switch -c sync/qdrant-vNEW main
git merge vNEW                 # conflicts appear ONLY where the deltas above overlap upstream's changes

# resolve using the delta table, then re-verify each delta + bump toolchain if required
cargo build                   # full workspace (needs protoc)
cargo test -p segment --lib

# land it and re-tag
git switch main && git merge --ff-only sync/qdrant-vNEW
git tag qdrant-vNEW-baseline vNEW     # marks the upstream release we're based on
git tag vNEW-trecall.0 main           # our released state
git push origin main --tags
```

Then re-pin any consumer submodule (e.g. clyffy `deps/trecall`) to the new `main`.

## Drift check

`qdrant-v<ver>-baseline` always marks the upstream release `main` is merged up to. Before assuming the fork is
current: `git fetch upstream --tags && git tag -l 'v1.*' | sort -V | tail -1` vs our latest `qdrant-*-baseline`.
