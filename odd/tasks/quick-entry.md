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
- [ ] Q1: Pure silver parser and formatter round trip (`Farm.parseSilver`), wired into all silver fields in FarmView and BlackzoneView. Route: delegated writer.
- [ ] Q2: Remembered choices, repeat last expense, "Morí con este set", Enter/focus behavior. Route: same writer.
- [ ] Q3: README updates. Route: same writer.
- [ ] S1: Large window spike (report only, throwaway plugin outside the repo, cleaned up). Route: delegated spike worker.

## Delivery
`single-pr` on branch `feat/quick-entry`. RDD is off (global).

## Progress / evidence
