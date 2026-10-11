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
- [ ] W1: Manifest kinds and `Window.qml` shell (wifiqr pattern): tabs, its own DataStore, open/close, Esc. Button in the bar panel. Route: delegated writer.
- [ ] W2: `wide` two-column layout for FarmView and BlackzoneView inside the window, with the bar panel unchanged. Route: same writer.
- [ ] W3: README covering the window, the button, the optional Hyprland bind, and the need to run `omarchy restart shell` after updating if the window does not open. Route: same writer.

## Delivery
`single-pr` on branch `feat/large-window`. RDD is off (global).

## Progress / evidence
