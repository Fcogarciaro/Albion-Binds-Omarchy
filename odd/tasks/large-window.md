# Large window (panel kind)

## Objective
Give the user a large floating window for data entry, besides the ~380px bar panel. User approved on 2026-10-11, after the spike in `odd/tasks/quick-entry.md` (S1).

## Decisions
- **Manifest:** `kinds: ["bar-widget","panel"]`, `entryPoints.panel: "Window.qml"`. This is the shape the spike validated (S1 evidence).
- **Window type:** the stock pattern from wifiqr (plugins/panels/wifiqr/Panel.qml:25-88, 213-220).
  - A root `Item` with `opened`, `open(payload)` and `close()`.
  - Inside it, a `PanelWindow` with `WlrLayershell.layer: Overlay` and `keyboardFocus: Exclusive`, centered, about 1000x700 and clamped to the screen.
  - A scrim, with Esc and click-outside closing it.
  - No `FloatingWindow`: Hyprland tiles it and ignores its size.
- **Content:** tabs **Cultivos | Zona negra**, reusing `farm/FarmView.qml` and `blackzone/BlackzoneView.qml`.
  - **Atajos stays in the bar panel only.** Binds live in the shell settings and the apply logic lives in Panel.qml, so the window does not touch binds.
  - In the wide window, views use two columns where it helps: forms on the left, summary and history on the right. In the bar panel they keep the single-column layout. A `wide` flag is passed in.
- **Data:** the window has its own `DataStore`.
  - Writes from the bar panel and the window reach each other through the existing live reload (`Storage.reloadOutcome`, own-echo skip).
  - The writer must check that no save is lost when both are open. Last write wins per document, and that is acceptable.
- **Opening it:**
  - A button "Abrir ventana grande" in the bar panel runs `omarchy-shell shell toggle fcogarcia.albion-companion '{}'`, via `BarWidget.run` or `Process`.
  - The README documents an optional Hyprland bind with the same command.
- UI copy is in Spanish. Code is in English.

## TDD
- Strict, ON (session config). Runner: `npm test`.
- Any pure logic (e.g. layout decisions, a payload parser) is test-first.
- qmllint with `-I ~/.cache/qsl`: 0 errors, no new categories.
- The delegate-id check reports 0.
- The shell is not live here. `fcogarcia.albion-companion` is NOT installed on this dev PC, so do not install it or touch the live shell.

## Tasks
- [x] W1: Manifest kinds and `Window.qml` shell (wifiqr pattern): tabs, its own DataStore, open/close, Esc. Button in the bar panel. Route: delegated writer.
- [x] W2: `wide` two-column layout for FarmView and BlackzoneView inside the window, with the bar panel unchanged. Route: same writer.
- [x] W3: README covering the window, the button, the optional Hyprland bind, and the need to run `omarchy restart shell` after updating if the window does not open. Route: same writer.

## Delivery
`single-pr` on branch `feat/large-window`. RDD is off (global).

## Progress / evidence

### W1 (writer) - ce3e786
- Manifest: `kinds: ["bar-widget","panel"]`, `entryPoints.panel: "Window.qml"`. No `panel` block is needed: wifiqr has none (`/usr/share/omarchy/shell/plugins/panels/wifiqr/manifest.json`); the bar-widget block stays.
- Loader: shell.qml:1296-1337 (one Loader per panel entry, active while `openPanelIds[id]`); injects `omarchyPath`, `shell`, `manifest` if declared (1340-1345). A mixed bar-widget+panel plugin is NOT treated as a bar-widget panel (shell.qml:1143-1148), so `toggle` goes to the panel loader. `toggle` = `isPluginOpen ? hide : summon` (shell.qml:1214-1224), reading `item.opened`.
- `Window.qml`: root Item with `opened/open/close/dismiss`; `PanelWindow` Overlay + Exclusive focus (wifiqr Panel.qml:213-220); focus re-acquired with `Qt.callLater` after mapping (wifiqr Panel.qml:52-57); Esc through `PanelKeyCatcher` (blocked while a field is being edited, same as Panel.qml); scrim click closes; card min(1000x700, screen-32) centered; header Cultivos | Zona negra via `ButtonGroup`; Cerrar button; own `DataStore`; content in a `Flickable`.
- Owner: `QtObject { store: dataStore; bar: QtObject { foreground: Color.popups.text; fontFamily: Style.font.family } }`. The views only read `owner.store`, `owner.bar.foreground`, `owner.bar.fontFamily` (rg over both views). Card colors: `Color.popups.background/border`. Views not duplicated; only a `wide` flag was added.
- Button "Abrir ventana grande" in Panel.qml (visible on Cultivos / Zona negra tabs): closes the panel, then `root.bar.run(...)` (same call stock widgets use for `omarchy-shell shell toggle`: plugins/menu/BarWidget.qml:21; Ui/PluginBarApi.qml:84-86), with a `Process` fallback if `bar.run` is missing.
- Concurrency (DataStore.qml / Storage.js): each store writes the whole document with atomic rename. The other store's FileView sees `fileChanged`; if it has `pendingWrites > 0` it defers (`reloadPending`, DataStore.qml `onFileChanged`) and reloads after `writeDone`; otherwise reloads at once. `reloadOutcome` (Storage.js:105-111) skips its own echo (`text === lastWritten`) and applies a foreign document. So a stale read never overwrites newer in-memory edits, and an edit in one surface reaches the other's memory within a file-watch round trip. Caveat (last write wins per document): edits committed in both surfaces inside that few-ms window would drop the earlier one. Unsaved text in a form is never in the document, so it is unaffected. The window store is recreated on every open (Loader unloads on hide), so it always starts from disk.
- TDD: test-first. RED: manifest test failed (`[bar-widget]` vs `[bar-widget, panel]`). GREEN: `npm test` 185/185 (was 184).
- qmllint (`-I ~/.cache/qsl`): 0 errors. Window.qml: missing-property + uncreatable-type (PanelWindow). Panel.qml: missing-property 6 -> 11, from the new `bar.run`/Style lines (same category). Views unchanged (129/39 and 166/43). No new categories.
- Delegate-id check (/tmp/delegate_ids.py over Panel, Window, both views, binds): 0.
- Smoke-load: scratch `qs -p` config in `~/.cache/qsl-smoke` (copies of Commons/Ui + plugin files, generated qmldirs); Window.qml and Panel.qml load Ready, views instantiate, tab switch works, no warnings. The window was not opened (no overlay on the live session).

### W2 (writer) - ef3f11b
- Both views: a hidden `Row { lanes }` (leftLane / rightLane Columns) is declared first; each top-level section sets `parent: view.wide ? leftLane|rightLane : view`. With `wide: false` every section stays a direct child of the root Column, so the bar layout is unchanged.
  - Farm: left = Parcelas, Planificador, Plantar/Cosechar form, error text, Impuesto; right = Resumen, Historial.
  - Zona negra: left = Sets, Muerte, Botín, Gasto, error text; right = Resumen, Historial. The Sets separator is hidden when wide (first in its lane).
- No ids moved and no behavior code touched (quick entry, two-tap delete, focus, `editing` unchanged).
- Check: a scratch harness instantiated both views with a real DataStore. Narrow heights are identical to the pre-change views (Cultivos 267, Zona negra 355); wide lays out shorter (217 / 252) in a 940px lane pair.
- No pure logic, so no new tests. `npm test` 185/185. qmllint 0 errors, counts identical to before (farm 129 unqualified / 39 missing-property; blackzone 166 / 43). Delegate-id check: 0. Window.qml smoke-load (scratch `qs -p`) still clean.

### W3 (writer) - edfed32
- README: new section "🪟 Ventana grande" (before the Nextcloud section) plus a pointer in the intro. Covers: button (Cultivos/Zona negra tabs), Esc / Cerrar / click-outside / Tab, Atajos stays in the bar panel, optional bind, last-write-wins note, and `omarchy restart shell` if the window does not open after updating.
- Bind: Omarchy keeps personal binds in `~/.config/hypr/bindings.lua` (template header and an existing `o.bind(..., "omarchy-shell shell toggle mirador '{}'")` entry there). Line: `o.bind("SUPER + ALT + A", "Albion Companion", "omarchy-shell shell toggle fcogarcia.albion-companion '{}'")`.
- Docs only; `npm test` 185/185.
