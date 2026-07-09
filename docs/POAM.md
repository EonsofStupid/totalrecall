# TotalRecall — Plan of Action & Milestones (POA&M)

**Artifact type:** POA&M — the guided schema this fork adheres to. Every objective has an ID, a definition of
done, milestones, and an honest status. No item is marked complete without evidence.

**What TotalRecall is:** Qdrant, forked to be embedded — the vector/recall engine for Clyffy/DevPulse. Identity =
TotalRecall (shortcode `trecall`); internals = pristine Qdrant (so upstream syncs stay diff-based). See
[README.md](../README.md).

**Status legend:** ✅ done · 🟡 in progress · ⬜ not started · 🔵 planned/later

---

## 1. Milestone summary

| ID | Objective | DoD (evidence) | Status |
|----|-----------|----------------|--------|
| **TR-0** | Official fork baseline | single clean `main`, zero rro, full `cargo build` green | ✅ |
| **TR-1** | Upstream alignment discipline | documented diff-sync + baseline-tag convention + drift check | 🟡 |
| **TR-2** | Embeddable surface (`lib/edge`) | server/consensus feature-gated OFF; `edge` is the stable in-process API | ⬜ |
| **TR-3** | TotalRecall facade crate | one `trecall` crate re-exporting the `edge` surface as the public contract | ⬜ |
| **TR-4** | DevPulse/Clyffy bridge | `clyffy-storage` `VectorStore` adapter over `edge`; map(SurrealDB)↔treasure(TotalRecall) | ⬜ |
| **TR-5** | Edge capabilities wired | hybrid (bm25+dense), quantization tiers, on-disk/mmap, per-project collections | 🔵 |
| **TR-6** | Harness branch-out | TotalRecall reusable as an embedded recall core behind a stable API (later: WardenClyffe) | 🔵 |
| **TR-7** | Public release readiness | readiness DONE (CI/community/logos removed · NOTICE · not-affiliated · Actions off · umbrella=separate-repos); flip gated on connectome | 🟡 |

---

## 2. Objectives in detail

### TR-0 — Official fork baseline ✅ (2026-07-02)
- Qdrant **v1.18.2** (current latest), orphan-rooted single clean commit; no rro branches/tags/history in the repo.
- Local deltas: `rust-toolchain.toml` stable 1.96; `geo` 0.32 pin in `lib/segment` (one `geo` alongside
  `surrealdb-core`); LFS artifact removed.
- **Evidence:** `cargo build` full workspace green on GB10 (aarch64, stable 1.96, needs `protoc`); tag
  `qdrant-v1.18.2-baseline`.

### TR-1 — Upstream alignment discipline 🟡
**Objective:** stay current with `qdrant/qdrant` cheaply and provably, forever.
- [x] Diff-based sync procedure documented (README "Syncing with upstream").
- [x] `qdrant-v<ver>-baseline` tag marks the exact upstream release the tree is based on.
- [ ] **M1.1** — `docs/UPSTREAM_ALIGNMENT.md`: the SSOT list of local deltas (toolchain pin, geo pin, LFS
      removal) so a sync knows exactly what to re-apply. *(target: next session)*
- [ ] **M1.2** — a `xtask`/CI check that fails if the tree's baseline tag lags the latest Qdrant release
      (surfaces drift instead of silently rotting).
- **DoD:** a newcomer can run the sync to a new Qdrant release from the docs alone, re-apply the delta list,
  and retag — no tribal knowledge.

### TR-2 — Embeddable surface via `lib/edge` ⬜
**Objective:** make the *embedded* engine, not the server, the product surface.
- `lib/edge` already composes `segment + shard + sparse + bm25 + wal` into an in-process engine
  (search/query/retrieve/scroll/facet/snapshots/optimize/bm25_embed) with **no** actix/consensus/distributed layer.
- [ ] **M2.1** — feature-gate the server bins (`default-run = "qdrant"`, actix, consensus) behind an off-by-default
      `server` feature so a default build is the embeddable core only.
- [ ] **M2.2** — pin `edge`'s public API as the TotalRecall contract; document it in `docs/EMBEDDING.md`.
- **DoD:** `cargo build -p edge` is the canonical build; the server is opt-in.

### TR-3 — `trecall` facade crate ⬜
**Objective:** consumers depend on `trecall`, not on `edge`/`segment` internals.
- [ ] **M3.1** — add a thin top-level `trecall` crate that re-exports the `edge` surface + a stable `TotalRecall`
      handle (open/collection/upsert/search/close). Internals stay Qdrant; the *name* consumers see is TotalRecall.
- **DoD:** `use trecall::{TotalRecall, ...}` compiles and drives an in-process instance.

### TR-4 — DevPulse/Clyffy bridge ⬜  (the map & treasure fusion)
**Objective:** wire TotalRecall into the clyffy recall path as the treasure, behind the port.
- [ ] **M4.1** — `clyffy-storage/src/adapters/trecall/` implements `VectorStore` over the `trecall` facade
      (feature `trecall`); `cargo check -p clyffy-storage --features trecall` green.
- [ ] **M4.2** — the fusion layer: SurrealDB (map: graph/relationships/breadcrumbs) resolves the route → TotalRecall
      (treasure: vectors) does ANN. Kept a **separate, modular** layer (no blur) so the "combine into one true
      TotalRecall core" question stays testable.
- [ ] **M4.3** — telemetry: `Vsig` recall spans (`gen_ai.*`/`devpulse.*`).
- **DoD:** a clyffy recall does map→treasure end-to-end on operator data; recall ≥ target on a golden set.

### TR-5 — Edge capabilities wired 🔵
**Objective:** use the levers, not stock defaults (per `VECTORDB_SIZING_SPEC.md`).
- Hybrid retrieval (`bm25_embed` + dense rescore); quantization tiers (int8/binary/PQ); `on_disk`+mmap; per-project
  collections (`proj_<slug>__chunks|symbols`); capacity profiles resolved from clyffy `ResourceProfile` — nothing hardcoded.
- **DoD:** the massive-tenant smoke (≥1M vectors, resident RAM < 128 GB shared with the brain, recall ≥ 0.95 binary+rescore).

### TR-6 — Harness branch-out 🔵 (focus stays TotalRecall; this is the payoff)
**Objective:** TotalRecall becomes a reusable embedded recall core other harnesses embed the same way.
- The `trecall` facade (TR-3) + the modular fusion (TR-4) are exactly what lets a *second* consumer (later,
  WardenClyffe) embed the same core behind the same stable API without touching Qdrant internals.
- **DoD:** a second harness consumes `trecall` unchanged — proof the core is genuinely reusable.

### TR-7 — Public release readiness 🔵 (flip to public when connectome lands)
The repo is a **grafted fork** (real Qdrant ancestry; `git merge` upgrades — see [UPSTREAM_ALIGNMENT.md](UPSTREAM_ALIGNMENT.md))
and is private but public-**ready**. Before `gh repo edit --visibility public`:
- [x] **Actions disabled** repo-wide (belt-and-suspenders; even a re-merged workflow can't run).
- [x] **CI removed:** deleted `.github/workflows/*` + `.github/actions/*` (Qdrant release/docker/edge-publish). A
      minimal TotalRecall CI can be added when useful.
- [x] **Community files:** removed `.github/ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`, `review-rules.md`,
      `dependabot.yml`, `codecov.yml`, `docs/CODE_OF_CONDUCT.md`; replaced `CONTRIBUTING.md` with a fork note.
      (`docs/DEVELOPMENT.md` kept — technical build guide, applies to the fork.)
- [x] **Trademark:** removed Qdrant logos (`docs/logo*.svg`); README carries a "not affiliated / not endorsed by
      Qdrant" note + attribution ([NOTICE](../NOTICE)).
- [x] **Secret scan:** clean — our fork-layer additions carry no secret material; Qdrant's grafted history is
      already public (nothing new to leak).
- [x] **License/attribution:** `NOTICE` added; GitHub detects Apache-2.0 (`.license.spdx_id = apache-2.0`).
- [x] **Umbrella (decided 2026-07-08):** **separate repos consumed by an umbrella** — TotalRecall and connectome
      stay independent repos; the umbrella pulls them as submodules / git-deps (same pattern as clyffy →
      `deps/trecall`). Keeps Qdrant's grafted history out of the umbrella; each piece versions + goes public on
      its own cadence.

Removed upstream files are documented for re-removal on merge in [UPSTREAM_ALIGNMENT.md](UPSTREAM_ALIGNMENT.md).
- **DoD:** readiness is complete; the actual flip (`gh repo edit --visibility public`) + a final secret re-scan
  happen when connectome lands.

---

## 3. Guardrails (adhere to)
- **No rro.** `rro` is context/lineage only (archived out-of-repo); the repo carries none of it.
- **Internals stay Qdrant** — never sed-rename crates; identity layer only. Upstream syncs must stay diff-clean.
- **No faked green** — a feature/adapter is a real seam or it doesn't ship marked done.
- **Evidence on the GB10**, not in theory (build/recall proven on the real box).
