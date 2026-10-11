# Phase 2a: Farm profit log (Cultivos)

## Objective
Turn the Cultivos tab into a real profit log for the user's island. The user owns one island with several plots and rotates crops by price. Each growth cycle per plot is recorded (planted, then harvested), and the plugin shows the real profit per cycle, per plot and in total.

## Problem / Why
Albion has no API for island state, so the user cannot see what a rotation actually earned. Market prices are crowd-sourced through the Albion Online Data Project and can prefill price fields, but the user's actual numbers win.

## Decisions
- Scope: **crops only** (T1 carrot to T8 pumpkin). Herbs and animals are out of scope for now.
- The rotation planner ("which crop pays most right now") is **phase 2b**, not this feature.
- Data lives in `farm.plots` / `farm.cycles` of `~/.local/share/albion-companion/data.json` (DataStore from phase 1). The document stays at `version: 1`, because the farm arrays were empty placeholders until now. Malformed entries are dropped on parse.
- Plot: `{ id, name }`.
- Cycle:
  ```
  { id, plotId, crop, plantedAt, seedsPlanted, seedPrice,
    harvestedAt|null, cropsHarvested, seedsReturned, cropPrice }
  ```
  An open cycle has `harvestedAt: null`. At most one open cycle per plot.
- Profit of a closed cycle:
  ```
  cropsHarvested * cropPrice * (1 - taxRate) + (seedsReturned - seedsPlanted) * seedPrice
  ```
  Seeds are valued at the price entered when planting.
- Tax rate: `farm.settings.taxRate`, default `0.065` (4% premium sales tax plus 2.5% sell-order setup fee). Editable in the tab.
- Prices: optional prefill from `https://west.albion-online-data.com/api/v2/stats/prices/<IDS>?locations=<city>&qualities=1`.
  - Default server is `west` (Americas).
  - City is chosen in the tab.
  - `sell_price_min == 0` means there is no data, so the field is left empty.
  - The user can always type the price.
  - A network failure never blocks logging.
- Item ids were verified live on 2026-10-11 (see T1 evidence for the full crop/seed check):
  - Crops: `T4_TURNIP`, `T6_POTATO`, `T8_PUMPKIN`.
  - Seeds: `T4_FARM_TURNIP_SEED`.
  - Remaining ids follow the same `T<n>_<CROP>` / `T<n>_FARM_<CROP>_SEED` pattern. They must be checked once against the API before they are hardcoded.
- UI copy is in Spanish (the existing panel is Spanish). Code, comments and identifiers are in English.

## TDD
- Strict, ON (session config). Runner: `npm test` (`node --test "tests/**/*.test.mjs"`).
- QML is not executable here. Run `qmllint` (/usr/lib/qt6/bin/qmllint) on the changed QML files.

## Tasks
- [x] T1: `farm/Farm.js`, pure and test-first. Contents:
  - Crop catalog (tier, Spanish name, crop id, seed id).
  - Plot and cycle sanitizing (wired into `Storage.parseData`).
  - `addPlot`, `plantCycle`, `harvestCycle` (returning new data, immutable).
  - `cycleProfit`, plus totals per plot, per crop and overall.
  - Route: delegated writer.
- [x] T2: `farm/Prices.js`, pure and test-first: build the API URL and parse the response into `{ itemId: price | null }`. The QML fetch uses `XMLHttpRequest` only if a stock shell plugin proves it works there. Otherwise prices stay manual and the evidence is recorded. Route: same writer.
- [x] T3: `farm/FarmView.qml`. Contents:
  - Plots list with the open cycle state.
  - Add plot.
  - Plant form (crop, seeds, seed price) and harvest form (crops, seeds returned, crop price) with price prefill.
  - Closed-cycle history with profit, plus totals.
  - Tax field.
  - Saves through `dataStore`.
  - Route: same writer.
- [x] T4: README section "Cultivos": how to log a cycle, how profit is computed, where the data lives. Route: same writer.

## Acceptance criteria
- `npm test` green, with new tests covering profit math, sanitizing and price parsing.
- `qmllint` has no new errors on the changed QML.
- Existing data files (empty farm arrays) load unchanged.

## Delivery
`single-pr` on branch `feat/farm-log`. RDD: per user-owned switch.

## Progress / evidence

### T1 (writer) - 5bb4831
- API check (west server, 6 royal cities, quality 1): all 16 ids returned sell_price_min > 0 except `T2_FARM_BEAN_SEED` (all cities 0, no market listing at the time). That id is CONFIRMED to exist by the ao-bin-dumps item list (`T2_FARM_BEAN_SEED: Bean Seeds`, raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/items.txt), so it is kept; its price prefill will often be empty. Price-confirmed: T1_CARROT, T1_FARM_CARROT_SEED, T2_BEAN, T3_WHEAT, T3_FARM_WHEAT_SEED, T4_TURNIP, T4_FARM_TURNIP_SEED, T5_CABBAGE, T5_FARM_CABBAGE_SEED, T6_POTATO, T6_FARM_POTATO_SEED, T7_CORN, T7_FARM_CORN_SEED, T8_PUMPKIN, T8_FARM_PUMPKIN_SEED.
- RED: tests/farm.test.mjs failed to load (module missing); then storage tests: 10 failing after adding the new expectations. GREEN: `npm test` 87/87 (63 before).
- farm/Farm.js is `.pragma library`, independent. Farm shape is `{ plots, cycles, settings: { taxRate } }`. Also exports parseInteger/parsePercent/formatPercent/formatSilver for the view.
- Storage wiring: `Storage.parseData(text, sanitizeFarm)` takes an injected sanitizer; Storage itself validates `farm.settings.taxRate` (default 0.065). `DataStore.qml` imports `../farm/Farm.js` (relative parent JS import: stock pattern plugins/notifications/components/NotificationCard.qml:10) and passes `Farm.sanitizeFarm`. Files with empty farm arrays load as before plus the default settings; version stays 1.
- qmllint shared/DataStore.qml: same single baseline warning (QProcess::ExitStatus) before and after.

### T2 (writer) - 86a337e
- RED: tests/prices.test.mjs failed to load (module missing); GREEN: `npm test` 96/96 (87 before; 9 new).
- farm/Prices.js: `buildUrl(ids, city, server)` (unknown server falls back to west, unsafe ids dropped, city URI-encoded), `parsePrices(json, city, wantedIds?)` -> `{ok, prices}` / `{ok:false, error}` (0, negative or non-numeric -> null; lowest non-zero price when a city repeats an item), `CITIES`, `SERVERS`.
- Fetch mechanism: XMLHttpRequest is NOT proven in stock plugins (`rg "XMLHttpRequest|fetch\("` over /usr/share/omarchy/shell: no hits; the only hits are third-party mirador test files under ~/.config/omarchy/plugins, which is not proof). Stock pattern used instead: `Process { command: ["curl","-fsS","--max-time",N,url]; stdout: StdioCollector { waitForEnd: true; onStreamFinished } }` at /usr/share/omarchy/shell/plugins/panels/weather/Panel.qml:186,277,335,419-429. T3 uses it.

### T3 (writer) - 895ec5c
- Farm.js gained `openCycle(farm, plotId)` and `closedCycles(farm, limit)` (+2 tests, `npm test` 98/98; written together with the code, so no separate RED was observed for these two).
- farm/FarmView.qml replaces the placeholder: summary (total profit), plots list (open-cycle state, per-plot total, Plantar/Cosechar button), add plot, shared plant/harvest form (crop dropdown, integer fields, live estimated profit on harvest, city dropdown + "Precio de mercado" prefill), last 8 closed cycles with profit, editable sales tax (%). Every change goes through `commit(result)`: replaces `store.document` and calls `saveData()`; errors are shown in Spanish.
- Panel.qml: exposes `readonly property var store: dataStore`; FarmView gets `id: farmView` and `catcher`; `editing` also covers the farm tab so the key catcher is blocked while typing.
- Price prefill uses the stock Process+curl+StdioCollector pattern (weather Panel.qml:186,419-429). `curl --max-time 8`; any failure/empty/zero only sets a status message, fields stay editable.
- qmllint: plain run only shows unresolved `qs.*` imports (baseline, same for BindsView). With a symlink dir exposing the shell as module `qs` (`-I <dir containing qs -> /usr/share/omarchy/shell>`) the imports resolve; FarmView.qml and Panel.qml then show only the baseline categories (Unqualified access of `owner`/ids inside delegates, `Style.font.*` "not found on QObject") identical to BindsView.qml, plus the baseline QProcess::ExitStatus warning in Panel.qml. No new error classes.
- NOT verified: QML never run in the live shell (layout at 380px, Dropdown inside Row, focus handling).

### T4 (writer) - c9f4747
- README: new section "Cultivos" (how to log a cycle, profit formula, 6.5 % default tax, price prefill caveats, data location); tabs bullet and intro no longer say Cultivos is upcoming; "Cómo funciona" bullet now states data.json holds the Cultivos data. Docs only; `npm test` 98/98.

## Final verification
- `npm test`: 98/98. qmllint: no new error classes (see T3). QML never run live.

### Parent check
- Spot check: `npm test` 98/98 re-run by parent.
- RDD off (global). `gentle-ai review assess --base-ref main --committed-only` (untracked `.atl/` excluded): risk medium (executable_change), 1429 changed lines. Writer self-verification accepted (non-small model); no independent verifier per tier table.
- Branch exceeds the ~400-line budget; delivery stays `single-pr` as recorded.
- Next step: user live test in the shell (needs push/merge, since `omarchy plugin update` pulls from GitHub).

## Follow-up: delete (requested 2026-10-11 after live test)
User live-tested the tab (plots, plant, prefill, persistence OK; harvest not yet tested). Missing: no way to fix a wrong entry.
- Decisions: delete a cycle (open = cancel planting, closed = drop from history and totals); delete a plot removes its cycles too. Both need a two-tap confirm in the view ("Eliminar" -> "¿Seguro?"), no modal dialogs.
- [ ] T5: `Farm.removeCycle(farm, cycleId)` and `Farm.removePlot(farm, plotId)`, pure, immutable and test-first. Delete controls in `FarmView.qml` for the open cycle, history rows and plots. Branch `feat/farm-delete`. Route: delegated writer (2 non-trivial files).
