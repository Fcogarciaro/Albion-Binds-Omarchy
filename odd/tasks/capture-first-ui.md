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
- [ ] U1: Pure helpers plus `ui.tab` (test-first). Route: delegated writer.
- [ ] U2: Zona negra restructure. Route: same writer.
- [ ] U3: Cultivos restructure. Route: same writer.
- [ ] U4: Wide layout check, README screenshots/text updated to the new flow. Route: same writer.

## Delivery
`single-pr` on branch `feat/capture-first-ui`. RDD is off (global).

## Progress / evidence
