# Phase 1: Albion Companion restructure

## Objective
Rename the plugin to **Albion Companion**, change its id to `fcogarcia.albion-companion`, and restructure it by feature. This prepares the farming tracker (phase 2) and the black zone tracker (phase 3). The keybinds must keep working exactly as before.

## Problem / Why
The plugin is growing beyond keybinds. Everything currently lives in one `Model.js` and one 380 px panel. The user approved changing the id while they are the only user. Changing the id means reinstalling on every PC, and the binds are recovered through export/import.

## Decisions
- New id `fcogarcia.albion-companion`. Display name "Albion Companion". Version `2.0.0`.
- Hyprland file: `~/.config/hypr/albion-companion.lua`. Module `hypr.albion-companion`. Loader marker `pcall(require, "hypr.albion-companion")`.
- **Legacy cleanup (automatic):** `apply.sh` removes the old `albion-binds` loader line and its comment from `hyprland.lua`, and deletes `~/.config/hypr/albion-binds.lua` if it exists. The user does not need to clean up by hand.
- Binds stay in the shell settings (`shell.json`), as today.
- Tracker data (phases 2 and 3) goes to `~/.local/share/albion-companion/data.json` through a storage component. Phase 1 creates only the skeleton (versioned empty document plus load/save), with no feature data yet.
- **Backup:**
  - New file `~/albion-companion.json`, with `app: "albion-companion"`.
  - Import must still accept old `albion-binds` files. If the new file is missing, it falls back to `~/albion-binds.json`. This is the migration path.
- **UI:** the bar panel gets tabs **Atajos | Cultivos | Zona negra**.
  - Atajos holds the current content.
  - Cultivos and Zona negra show a "Próximamente" placeholder.
- **Large window (`panel` kind):** only if a stock pattern shows a bar widget opening its own plugin's panel. Otherwise it is deferred to phase 2 and the evidence is reported.
- The GitHub repo name stays the same for now. The old URL keeps working.

## Target structure
```
manifest.json
Panel.qml                  # bar widget shell: icon + tabs only
binds/Binds.js             # former Model.js (binds logic + generateLua)
binds/BindsView.qml        # current bind list/add UI
binds/apply.sh
backup/Backup.js           # exportBinds/parseImport (+ legacy app support)
shared/Storage.js          # pure: default document, migrate/validate
farm/FarmView.qml          # placeholder
blackzone/BlackzoneView.qml # placeholder
tests/...
```
The exact split may be adjusted to what QML imports allow. Relative `import "binds/Binds.js" as Binds` and subdirectory QML components need to be verified.

## TDD
- Strict, ON. Runner: `npm test`.

## Tasks
- [x] T1: Move `Model.js` into feature modules (`binds/`, `backup/`) with no behavior change. Update the test loader and keep the suite green. Route: delegated writer.
- [ ] T2: Rename the id, the Lua module and the marker. Add legacy cleanup to `apply.sh`, test-first. Route: same writer.
- [ ] T3: Backup: new app id and path, accept legacy `albion-binds` files, fall back to `~/albion-binds.json` (test-first for the pure parts). Route: same writer.
- [ ] T4: `shared/Storage.js` skeleton (default doc, version, validate), test-first, plus a FileView-backed load/save in QML. Route: same writer.
- [ ] T5: Tabbed bar panel (Atajos, Cultivos, Zona negra) and `BindsView.qml` extraction. Research the `panel` kind and either add the window skeleton or document why it is deferred. Route: same writer.
- [ ] T6: README: new name, fresh install, migration from Albion Binds, uninstall. Route: same writer.

## Acceptance criteria
- `npm test` is green.
- The generated Lua is identical apart from names. The legacy cleanup is covered by `apply.sh` tests.
- Legacy backup files import correctly.

## Delivery
`single-pr` on branch `feat/companion-restructure`. RDD is off.

## Progress / evidence

### T1 (delegated writer, pure move)
- Model.js -> binds/Binds.js; export/import -> backup/Backup.js; apply.sh -> binds/apply.sh; tests split (binds/backup), loader generalized (`loadModule`).
- No `.import` of one JS from another is used by any stock plugin (rg `^\.import` over /usr/share/omarchy/shell: no hits), so modules stay independent; `sanitizeBinds` is injected into Backup functions.
- Verified: subdirectory JS import `import "../X.js" as X` (plugins/notifications/components/NotificationCard.qml:10), subdirectory components `import "components"` (plugins/notifications/Service.qml:11).
- Evidence: `npm test` 45/45 pass before and after.

