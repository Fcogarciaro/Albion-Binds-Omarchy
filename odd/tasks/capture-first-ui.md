# Capture-first UI (Zona negra + Cultivos)

## Objective
Cut clicks and visual clutter. The user approved the layout on 2026-10-12.

## Problem
- Zona negra stacks five collapsible sections, each with its own Mostrar/Ocultar button.
- History auto-opens.
- Sets sit at the top.
- Capturing loot, expenses and deaths takes many open/close clicks. Cultivos has the same pattern.

## Approved layout
**Zona negra:**
- Summary strip at the top: balance, plus ganado, perdido and gastado.
- Three primary actions: **+ Botín**, **+ Gasto**, **✝ Muerte**. The "↻ Repetir: <nota> −<valor>" chip sits under them when there is a previous expense.
- **One compose card at a time** opens below the actions. It has a ✕ close button, focuses its first field, and Enter saves. On a successful save the card closes and a brief "Guardado" notice shows.
- **Muerte card:** the user's sets appear as tap chips. It remembers the last set and fetches prices automatically on selection. Editable total, then Save.
- **History:** "Últimos movimientos" always shows the last 3 entries, with no toggle. "Ver todo ›" expands to the full list with two-tap delete. It never auto-opens.
- **"Mis sets (n) ›"** sits at the bottom, collapsed by default. The set editor lives inside it.

**Cultivos:**
- Summary at the top.
- Each plot is a card with its state: "Creciendo", "Lista para cosechar" or "Vacía". One contextual primary button (Plantar or Cosechar) opens that plot's compose card, under the same one-card-at-a-time rule.
- Recent cycles show the last 3, with "Ver todo".
- Planner, tax and add-plot go at the bottom, collapsed.

**Both tabs:**
- Remember the last open tab in `ui.tab`, synced through data.json.
- Large window (`wide`): capture on the left, summary and full history on the right.

## Constraints
- Data model, calculations and stored data are unchanged, except for the new optional `ui.tab`.
- Keep all existing behaviors:
  - silver shorthand
  - repeat expense
  - "Morí con este set" (it now opens the Muerte card with that set)
  - tomes
  - two-tap deletes
  - price prefill and planner
  - official Spanish names
- No Repeater-scoped id may be used outside its Repeater.
- Shared singleton `DataStore`.
- The shell theme and Ui components stay (Color, Style, Button, Dropdown, ButtonGroup, ...). This is a layout and interaction restructure, not a new visual identity.

## TDD
- Strict, ON (session config). Runner: `npm test`.
- Pure logic is test-first: recent-events slicing, plot state derivation, `ui.tab` sanitizing.
- qmllint with `-I ~/.cache/qsl`: 0 errors, no new categories.
- The delegate-id check reports 0.
- Smoke-load in a scratch `qs -p`, wide and narrow.

## Tasks
- [x] U1: Pure helpers plus `ui.tab` (test-first). Route: delegated writer.
- [x] U2: Zona negra restructure. Route: same writer.
- [x] U3: Cultivos restructure. Route: same writer.
- [x] U4: Wide layout check, README screenshots/text updated to the new flow. Route: same writer.

## Delivery
`single-pr` on branch `feat/capture-first-ui`. RDD is off (global).

## Progress / evidence

### U1 (writer) - 9c5e54e
- RED: 198 tests, 18 failing (new `plotState`/`plotStateLabel`/`ui.tab` tests plus the existing `ui` expectations now carrying `tab`). GREEN: 198/198 (was 189).
- `Farm.GROWTH_MS` (22 h in ms: the log stores `Date.now()`), `Farm.plotState(farm, plotId, now)` -> `empty | planted | ready` (never `ready` without a valid clock), `Farm.plotStateLabel`. The brief said "Plantada" for the planted label; the approved layout says "Creciendo", so the label is "Creciendo" (state key stays `planted`).
- `recentEvents(bz, n)` and `closedCycles(farm, n)` already existed: reused, extra tests for n = 3 (mixed types, fewer than n, no limit).
- `ui.tab` in `Storage.uiOr`: "binds" | "farm" | "blackzone", anything else -> "binds"; old files load unchanged, `DATA_VERSION` stays 1.

### U2 (writer) - 9e30ddb
- New shared pieces in `components/`: `ComposeCard.qml` (bordered card, title, ✕) and `Stat.qml` (label over value).
- `BlackzoneView`: summary (balance + Ganado/Perdido/Gastado) with "Guardado" at the right of the balance; actions + repeat chip; one compose card (`composer`); history 3 + "Ver todo"; "Mis sets (n)" collapsed. Old per-section Mostrar/Ocultar removed. Death card: set chips, auto price fetch on selection, remembered set, editable total (a late price answer no longer overwrites a typed total).
- Lines changed exceed the ~400 heuristic (full restructure of a 1300-line view); not split artificially.
- qmllint: missing-property + unqualified only (same categories as before), 0 errors. Delegate-id check: 0.

### U3 (writer) - 46fac86
- `FarmView`: summary (total + Parcelas/Creciendo/Listas), plot cards with state, one contextual button and a "⋯" area (two-tap Cancelar siembra / Eliminar parcela), one plant/harvest compose card below the plots (not inside the plot card: the field ids must stay outside the Repeater delegate), last 3 cycles + "Ver todo", collapsed Agregar parcela / Planificador / Impuesto. `nowMs` ticks every 60 s.

### U4 (writer) - c0cc1bb, 66cbb8b
- `DataStore.setTab(tab)`; Panel and Window read `store.document.ui.tab` (panel: Atajos|Cultivos|Zona negra; window: "binds" -> Cultivos), so both surfaces stay in sync through the shared store. `wide` layout: capture left, summary + full history (50 events / 20 cycles) right, no "Ver todo".
- README: Cultivos and Zona negra sections, remembered tab, ventana grande text.

### Checks
- `npm test` 198/198. qmllint (`-I ~/.cache/qsl`): Panel 11 missing-property + 1 signal-handler-parameters, Window 13 + 1 uncreatable-type (identical to base); FarmView 46 + 138 unqualified, BlackzoneView 50 + 177 (same categories, more code); DataStore 1; components 3 each. 0 errors.
- Delegate-id check (/tmp/delegate_ids.py: Panel, Window, FarmView, BlackzoneView, BindsView, components): 0.
- Smoke (scratch `qs -p ~/.cache/qsl-cf`, fake store with seeded data; harness in `~/.cache/qsl-harness`): both views, narrow 380 and wide 940, load without errors; Panel.qml and Window.qml load Ready, Window instantiates, `ui.tab` read from disk and written by `DataStore.setTab` (temp HOME). Death flow fetched real prices through curl.
- Default content heights (px, narrow 380 / wide 940, seeded: 3 plots, 2 sets, 5 events): Cultivos 653 -> 574 / 430 -> 359; Zona negra 728 -> 346 / 394 -> 280; Atajos unchanged. With a card open: Zona negra expense +176, loot +270.
- Not verified: live shell (not installed here), real pointer/keyboard typing (focus checked via `editing` in an offscreen window), the visual look.

## Fix: expense card no longer pre-fills the last note (user request 2026-10-12)
- The user found that after saving an expense, the next one re-showed the previous note. Cause: `openComposer("expense")` filled the note from `ui.expenseNote`.
- Fix: the prefill and the `rememberUi({ expenseNote })` write are removed, so the card always starts empty. Repeating an expense stays one tap through the "↻ Repetir" chip.
- `ui.expenseNote` stays in Storage sanitizing, so existing files remain compatible.
- QML only, so there is no pure logic to TDD. `npm test` 198/198, qmllint 0 errors.
