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
- [x] T1: `DataStore.qml` reloads on external file change (FileView watch). Avoid a reload loop on its own writes, and never drop a pending save. Verify the API in the Quickshell qmltypes. Route: delegated writer.
- [x] T2: Research the game yield constants with sources: crops per seed, seed return with and without premium/focus, and seeds per farm plot. Route: delegated research worker, read-only.
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

### T1 (writer) - d1de713
- Route: delegated writer. TDD strict, runner `npm test`: RED 5 failing (`Storage.reloadOutcome is not a function`, 103/108 pass), GREEN 108/108.
- Pure logic: `Storage.reloadOutcome(text, lastWritten, current, sanitize)` returns same / apply / error.
- API evidence: `/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes` FileView props `watchChanges` (:369), `atomicWrites` (:359), `blockWrites` (:349); signals `fileChanged`, `saved`, `saveFailed`, `loaded`, `loadFailed`; method `reload` (:493). Stock usage: `plugins/lock/Service.qml:484-490` (`watchChanges: true` + `onFileChanged: reload()`), `services/AppLibrary.qml:220-226`.
- Runtime-verified with `qs -p` on this machine: `fileChanged` keeps firing after rename-over (Syncthing style), in-place write, delete and re-create, so no re-arm is needed. An own `setText` (atomic) emits `fileChanged` after `saved`; two `setText` calls yield two `saved`. A `reload()` issued while another write is in flight may not emit `loaded`, so reloads are deferred until no write is pending.
- Behavior: own write echo is skipped (text equals `lastWritten`), so no flicker or loop; reloads are deferred while writes are pending (`pendingWrites` counter) and run after the last `saved`; a parse error keeps the document and sets `error`, cleared on the next good read; deleted file keeps the document.
- DataStore end-to-end run (HOME override): own save emitted no extra document change; external edit applied; invalid JSON kept doc plus error; delete kept doc; re-create applied and cleared the error.
- qmllint: only the baseline `signal-handler-parameters` warning (line moved).
- Unverified: FileView internals (inode vs path; source not installed), only observed behavior.

### T2 (research worker, parent spot-checked)
Source: ao-bin-dumps master, fetched 2026-10-11.
- https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/items.xml
- https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/loot.xml

Constants:
- Growth time: 79200 s (22 h), all tiers (`harvest growtime`).
- Crops per harvested seed, non-premium: 3 to 6, avg 4.5, all tiers.
  - Source: loot.xml `T<n>_<CROP>_LOOT amount="3-6"`.
  - The parent verified this for T8_PUMPKIN_LOOT.
- Premium doubles the crop yield (avg 9). Source: wiki snippet (https://wiki.albiononline.com/wiki/Crops). Medium-high confidence; it is not in the XML.
- Seed return per harvested plant, without focus (`<seed chance>`) and with focus (`chance + activefarmbonus`). The parent verified T8 activefarmbonus = 0.1333.

  | Tier | Crop | No focus | Focus |
  |---|---|---|---|
  | T1 | carrot | 0 | 2.0 |
  | T2 | bean | 0.3333 | 1.6667 |
  | T3 | wheat | 0.6 | 1.4 |
  | T4 | turnip | 0.7333 | 1.2667 |
  | T5 | cabbage | 0.8 | 1.2 |
  | T6 | potato | 0.8667 | 1.1333 |
  | T7 | corn | 0.9111 | 1.0889 |
  | T8 | pumpkin | 0.9333 | 1.0667 |

- Each harvest has a 10% chance of a T1_WORM. It is ignored.

Gaps, all exposed as editable planner settings instead of guessed:
- 9 seeds per plot comes from a forum/guide snippet only. Setting, default 9.
- Whether premium affects seed return is unknown. Assumed no.
- Focus cost (1000) is per plot or per seed: unknown. Not used in profit.
- Settings: premium (default on, consistent with the 4% tax), focus watering (default on), seeds per plot (default 9).
