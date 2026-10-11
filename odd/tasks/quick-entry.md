# Quick entry + large window spike

## Objective
- Make data entry faster and more intuitive in the Cultivos and Zona negra tabs.
- Find out whether the plugin can also open a large window.

## Decisions (user approved 2026-10-11)
- **Silver shorthand** in every silver field: `450k`, `1.2m`, `12,5k`, `1.500.000`, `1,500,000`. The parser is pure and tested, and an ambiguous input is rejected with a Spanish message.
- **"Repetir último gasto":** one tap re-logs the last expense (same value and note, new id and time).
- **Remember choices:** last city (death, planner, farm prefill), last death set and last expense note. They are per-viewer conveniences, stored in `data.json` under `ui` (they sync across PCs) or in the plugin's own settings. The writer picks one and documents it.
- **Enter saves** in every form. Opening a section focuses its first field.
- **"Morí con este set"** button on each set: opens the death form with that set selected and fetches prices.
- **Large window:** spike only, outside the repo. Can one manifest declare `["bar-widget","panel"]`, and can the bar widget open it via `omarchy-shell shell toggle <id>`? A decision on building it comes after the spike.

## TDD
- Strict, ON (session config). Runner: `npm test`.
- qmllint with the `qs` symlink.
- The delegate-id check: no Repeater-scoped id used outside its Repeater.

## Tasks
- [x] Q1: Pure silver parser and formatter round trip (`Farm.parseSilver`), wired into all silver fields in FarmView and BlackzoneView. Route: delegated writer.
- [x] Q2: Remembered choices, repeat last expense, "Morí con este set", Enter/focus behavior. Route: same writer.
- [x] Q3: README updates. Route: same writer.
- [x] S1: Large window spike (report only, throwaway plugin outside the repo, cleaned up). Route: delegated spike worker.

## Delivery
`single-pr` on branch `feat/quick-entry`. RDD is off (global).

## Progress / evidence

### Q1 (writer) - 07c8976
- RED: 6 new tests failed (179 total, 173 pass). GREEN: `npm test` 179/179.
- `Farm.parseSilver` and `Farm.formatShort` (for "12k" labels) added. Wired into seed price, crop price (and the harvest preview), death value, loot value and expense value. Quantities, seeds and tomes stay on `parseInteger`.
- Accepted: `1234`, `1.500.000`, `1,500,000`, `1 234 567`, `450k`, `1.2m`, `12,5k`, `2M`, `1.500k` (3 digits after a separator = thousands). Rejected: `1.5`, `1,5`, `-5`, `1.2.3k`, `1.500,000`, `12kk`, `.5k`, `1.2345k` (fractional silver), garbage.
- qmllint (`-I ~/.cache/qsl`, `/usr/lib/qt6/bin/qmllint`): 0 errors, 377 warnings identical to the base commit (354 unqualified, 100 missing-property, 2 signal-handler-parameters). Delegate-id check: 0.

### Q2 (writer) - c311d42
- RED: 13 new/updated tests failed (184 total, 171 pass). GREEN: `npm test` 184/184.
- Storage: `ui: { city, deathSetId, expenseNote }` in `data.json` (top level, version stays 1). `Storage.uiOr` validates each field; old files load with defaults. `Blackzone.lastExpense(bz)` is the pure helper.
- Views: city is one value shared by Cultivos (prefill + planner) and Zona negra; death set restored when the death form opens; expense note prefilled on open. "Repetir: <nota> −<valor>" button above the expense form (hidden without expenses). "Morí con este set" on each set row calls `view.diedWithSet(id)`; a price request made while another runs is queued.
- Enter: loot value/tomes, expense value, death value and plant price/harvest price save; middle fields of the plant/harvest chain still move to the next field. Opening a section focuses its first text field through `Qt.callLater` (planner has none: first control is a dropdown).
- qmllint: 0 errors, same three categories (383 warnings, +6 unqualified/missing-property from the new code). Delegate-id check: 0.
- Not run live in Quickshell.

### Q3 (writer) - f671b41
- README: shorthand table, "Repetir" expense button, "Morí con este set", remembered choices (`ui` in `data.json`), Enter and focus behavior. Docs only; `npm test` 184/184.

### S1 (spike worker, throwaway plugin, cleaned up)
- **Feasible.** A manifest with `kinds: ["bar-widget","panel"]` validates (services/PluginRegistry.qml:52,64,488-489).
  - shell.qml:1145-1148 routes a mixed plugin to the panel loader, and :1152-1225 and :1310-1337 load `entryPoints.panel`, calling `open(payload)` / `close()`.
  - `omarchy-shell shell summon <id> '{...}'` returned `ok`. `toggle` closed it.
  - A `.pragma library` JS file in the plugin dir was imported by both the widget and the panel.
- The widget can run the command with `BarWidget.run(command)` (Ui/PluginBarApi.qml:84-86) or a Quickshell `Process`.
- **Window:** `FloatingWindow` 900x650 was tiled by Hyprland (size ignored).
  - Use the stock `PanelWindow` with `WlrLayershell.layer: Overlay` and `keyboardFocus: Exclusive` (plugins/panels/wifiqr/Panel.qml:25-88, 213-220).
- **Unverified:**
  - Keyboard input in the window (could not type).
  - The widget button path (no clicks).
- Hyprland bind command: `omarchy-shell shell toggle fcogarcia.albion-companion '{}'`.
- **Cleanup:** the plugin was removed, its backup dir deleted, the shell rescanned, and `shell.json` is identical to the pre-test backup.
- Note: `fcogarcia.albion-companion` is not installed on this dev PC. The user runs it on other PCs.

### Parent check
- README "Registrar un gasto" moved from Cultivos to Zona negra (expenses belong to the black zone).
