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
- [x] T3 `fix(prices)`: request-scoped price answers.
  - Each answer is bound to the city, plot and crop of its request.
  - The planner refetches after a city change or a failed fetch.
  - Zona negra refetches on a city change.
  - The death card persists and fetches only when the set changes.
  - Optional `ui.server` setting.
- [x] T4 `fix(panel)`: binds hardening.
  - `applyProc` uses the exit code and clears `errorText` on success.
  - `apply.sh` keeps symlinks and cleans up its temp file with a trap.
- [x] T5 `refactor(ui)`: shared components and visual polish.
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

### T3 (writer)
- RED: 16 failing (new `ui.server`, `curlArgs`, `checkResponse`, `sameRequest` tests plus ui shape expectations). GREEN: `npm test` 210/210 (was 205).
- Prices.js: `curlArgs` (adds `--compressed`, status via `-w`, no `-f`), `checkResponse` (429 -> "El mercado limitó las consultas, intenta en un minuto.", other failures -> generic message), `sameRequest`, `SERVER_OPTIONS`. Storage `ui.server` (default west, old files load unchanged).
- FarmView: form price request captured (city, server, plot, mode, item) and applied only if it still matches; a stale answer is dropped and re-requested if the user had asked. Planner: request captured, `onPlannerKeyChanged` resets status (next open fetches even when closed), refetch after a failed fetch. Server selector in the planner.
- BlackzoneView: city/server change clears prices and the stale text and refetches when the death card is open; stale answers dropped by set/city/server; reopening the card on the selected set does not call `rememberUi` and refetches only if no prices are loaded. Server selector under the city row.
- qmllint (`-I ~/.cache/qsl`): FarmView 46 missing-property + 140 unqualified (base 46 + 138), BlackzoneView 50 + 179 (base 50 + 177), 0 errors.

### T4 (writer)
- RED: 3 failing apply.sh tests (symlinked legacy cleanup, symlinked target, failing mv leaves temp file); the plain symlinked-hyprland.lua append test already passed (`>>` follows links). GREEN: `npm test` 214/214 (was 210).
- apply.sh resolves `readlink -f` for the target and hyprland.lua, creates temps next to the real file, and an EXIT trap removes a leftover temp. Panel `applyProc`: exit code checked, generic Spanish error when stderr is empty, `errorText` cleared on exit 0.
- qmllint Panel: 11 missing-property + 1 signal-handler-parameters, identical to base. Tested only against temp dirs; the real ~/.config/hypr was never touched.
- No `qs -p` smoke load was run for T1-T4 (QML-only edits verified by qmllint).

### T5 (writer) - c766e1f, 21c23a4, 5ed6aa8
- Tests (pure JS, test-first): RED 1 file failing (ViewHelpers missing) then 1 wrong expectation of mine fixed; GREEN `npm test` 219/219 (was 214). New: `shared/ViewHelpers.js` (`shortDate` dd/MM/yy, `newId`), `Farm.signed`.
- c766e1f shared components in `components/`: ViewStyle (foreground/font, muted opacities 0.7 label and 0.6 secondary, spacing rhythm 4/8/12/16 via `Style.space`, one wide type scale 1.15), ViewText, ViewButton (roles action/compact/link/quiet = one font size per role), ViewField, FieldRow, ToggleRow, SectionToggle, HistoryRow, HistoryList, LaneLayout, DeleteConfirm, SavedNotice.
- 21c23a4 FarmView 1260 -> 550 lines (state and logic) + PlotCard, PlantHarvestForm, FarmSummary, FarmAddPlot, FarmPlanner, FarmTax. BlackzoneView 1452 -> 560 + BzSummary, BzActions, LootCard, ExpenseCard, DeathCard, SetsSection, SetCard, PieceForm. T3 request-scoping code moved verbatim. Rename field fixed (filled on card creation, follows the set name unless focused). Copy: "Escribe el valor o los tomos.", dates with the year, unused `findSet` and stale expense-note comments removed. `ui.expenseNote` stays in Storage.
- 5ed6aa8 Window: `Style.cornerRadius` on the card, scrim `Color.menu.scrim` (theme token; it is the background color at 50 %, no longer black), header on the wide scale; BindsView and Panel use the shared muted tokens and spacing.
- qmllint (`-I ~/.cache/qsl`, 0 errors everywhere). Per file, base -> now: FarmView 186 -> 11, BlackzoneView 229 -> 0, Window 14 -> 8, Panel 12 -> 12, BindsView 79 -> 80 (one more `unqualified` from a `look` id inside a delegate). New files: only `unqualified` for ids inside delegates (max 13 in SetsSection).
- Delegate-id check (/tmp/delegate_ids.py over Panel, Window, farm, blackzone, binds, components): 0.
- Smoke (scratch `qs -p ~/.cache/qsl-cf`, HOME in the scratchpad with seeded fake data.json): Harness (FarmView + BlackzoneView narrow 380 and wide 940), FarmFlow, Flow, RenameFlow and Smoke (Panel and Window compile Ready, Window instantiated and loaded on both tabs from the seeded file) show no QML errors or warnings. Default heights narrow/wide: Cultivos 580/397, Zona negra 340/299 (before T5: 574/359 and 346/280; spacing 14 -> 12 and field gaps 6 -> 8). RenameFlow: field shows "Set pvp" after the card is rebuilt.
- Not verified: the opened overlay window (it takes exclusive keyboard focus on the live compositor, so it was never mapped), real typing, the visual look of the wide scale and the scrim.
- Judged out of scope: ComposeCard/Stat moved to the theme API in the same commit as the view split (both views use them), so the split is one commit. `setPlannerCity` wrapper removed (it only called `setCity`). Dropdown/SearchableDropdown have no font size property, so they do not scale in the wide window.

## Next step
User live test, then merge.
