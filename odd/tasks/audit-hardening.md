# Audit hardening (data safety, prices, numbers, panel, UI polish)

## Objective
Fix the defects found in the 2026-10-12 read-only audit and polish the UI. The user authorized fixing everything, on the condition that no existing data is lost.

## Problem
- A failed first load of data.json can overwrite the real file with defaults.
- Price answers can be applied to the wrong city, plot or crop.
- "9.5" is parsed as 95.
- Errors stick on screen after the problem is gone.
- data.json is rewritten on every tab switch.
- The two large views duplicate most of their UI patterns.

## Constraints
- **No data loss.** The data.json schema stays backward compatible. Unknown and legacy fields (for example `ui.expenseNote`) are tolerated, never cause a load failure, and are never destructively migrated.
- Calculations and stored values stay unchanged, except for an optional `ui.server` and a snapshotted tax rate on new harvests.
- Every existing behavior listed in capture-first-ui.md is kept.
- Branch: `fix/audit-hardening`. One Conventional Commit per task. No AI attribution in commits.

## TDD
- Mode: strict (on). Source: session configuration (Strict TDD Mode: enabled).
- Runner: `npm test` (`node --test "tests/**/*.test.mjs"`).
- QML has no test harness. QML changes are checked with qmllint and a `qs -p` smoke load.

## Delivery
- RDD: off (global). No native review.
- Strategy: ask-on-risk. Forecast is over 400 lines because of the T5 refactor.

## Tasks
- [x] T1 `fix(store)`: data-loss guards.
  - A parse failure on the first load blocks saves, and `data.json.bak` is written before any overwrite.
  - No save happens before `loaded`.
  - `error` is cleared on a successful save.
  - `ui.tab` is persisted debounced or only with other writes, not on every switch.
- [x] T2 `fix(numbers)`: number parsing and display.
  - `parseInteger` accepts only valid thousands groups and is capped at MAX_SAFE_INTEGER.
  - `formatSilver` no longer shows "-0".
  - Harvest is tolerated when the clock is behind the planting time (clock skew).
- [ ] T3 `fix(prices)`: request-scoped price answers.
  - Each answer is bound to the city, plot and crop of its request.
  - The planner refetches after a city change or a failed fetch.
  - Zona negra refetches on a city change.
  - The death card persists and fetches only when the set changes.
  - Optional `ui.server` setting.
- [ ] T4 `fix(panel)`: binds hardening.
  - `applyProc` uses the exit code and clears `errorText` on success.
  - `apply.sh` keeps symlinks and cleans up its temp file with a trap.
- [ ] T5 `refactor(ui)`: shared components and visual polish.
  - Extract shared components and split FarmView and BlackzoneView.
  - Two muted tokens and a consistent spacing rhythm.
  - Fix the rename field after a set rebuild.
  - Large-window card radius and type scale.
  - Clearer copy, dates with the year, and dead code removed.

## Routes
- T1 to T5: delegated direct to one sequential writer. Trigger: more than 2 non-trivial files per task, and the preparation reads span more than 4 files.

## Progress / evidence
### T1 (writer)
- RED: 4 new tests failing (saveDecision, errorAfterSave missing). GREEN: `npm test` 202/202 (was 198).
- `Storage.saveDecision` (queue / block / write) and `Storage.errorAfterSave`. DataStore: `loadBlocked` (first-load parse error), `saveQueued` flushed after load, `saveFailed` flag so only a save error is cleared by a later successful save, `setTab` debounced 1.5 s (flushed on destruction).
- `data.json.bak` not written: while blocked the unparsable file is never overwritten, and saves resume only after a successful reload, so there is nothing to back up.
- qmllint DataStore (`/usr/lib/qt6/bin/qmllint -I ~/.cache/qsl`): 1 warning, identical to base.

### T2 (writer)
- RED: 4 failing (parseInteger groups, cap, formatSilver -0, harvest clock skew). GREEN: `npm test` 205/205 (was 202).
- `parseInteger` accepts one kind of separator in valid 3-digit groups only, capped at MAX_SAFE_INTEGER. `formatSilver` rounds before the sign (no "-0"). `harvestCycle` clamps `harvestedAt` to `plantedAt` instead of failing. Blackzone.js has no parseInteger; only QML callers (via Farm), so nothing else changed.

## Next step
T1.
