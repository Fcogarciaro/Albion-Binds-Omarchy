# Phase 2b: Rotation planner + live reload

## Objective
Two pieces of work:
- Show in the Cultivos tab which crop is expected to pay most per plot right now, so the user can decide the next rotation.
- Reload `data.json` when it changes on disk, so Syncthing can keep several PCs in sync.

## Problem / Why
The user rotates crops by price on one island with several plots, and wants to stop entering data on every PC.

## Decisions
- **Expected profit per crop, per plot cycle:**
  ```
  expectedCrops * cropPrice * (1 - taxRate) + (expectedSeedsReturned - seedsPerPlot) * seedPrice
  ```
- **Yield source:** the user's own history wins. For each crop, average the crops per seed planted and the seeds returned per seed planted over closed cycles.
- **No history:** use the game's estimated yield (user decision, 2026-10-11). The constants come from sourced research, and each row is labeled with its source: "historial" or "estimado".
- **Prices:** the AODP API for the selected city, the same Process+curl pattern as farm-log. A missing price means "sin precio", and that crop is ranked last.
- **Sync:** user-managed with Syncthing on `~/.local/share/albion-companion/`. The plugin only needs to reload on external change.
- Binds stay out of sync scope. They keep using Export/Import.
- UI copy is in Spanish. Code is in English.

## TDD
- Strict, ON (session config). Runner: `npm test`.
- `qmllint` for QML, with the `qs` symlink as in farm-log T3.

## Tasks
- [ ] T1: `DataStore.qml` reloads on external file change (FileView watch). Avoid a reload loop on its own writes, and never drop a pending save. Verify the API in the Quickshell qmltypes. Route: delegated writer.
- [ ] T2: Research the game yield constants with sources: crops per seed, seed return with and without premium/focus, and seeds per farm plot. Route: delegated research worker, read-only.
- [ ] T3: `farm/Planner.js`, pure and test-first: per-crop yield from history with a fallback to the estimates, expected profit and ranking. Route: delegated writer.
- [ ] T4: Planner section in `FarmView.qml`: city, fetch all crop and seed prices in one request, ranked list with source label. Route: same writer.
- [ ] T5: README: planner section, plus how to sync with Syncthing. Route: same writer.

## Acceptance criteria
- `npm test` green.
- No new qmllint categories.
- Every estimate constant cites a source in the code comment and in this doc.

## Delivery
`single-pr` on branch `feat/rotation-planner`. RDD is off (global).

## Progress / evidence
