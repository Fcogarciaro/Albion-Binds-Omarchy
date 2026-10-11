# Polish: fix bugs, harden and add tests

## Objective
Fix verified bugs in the Albion Binds plugin, harden the generated Hyprland Lua, and add an automated test suite before new features are added.

## Problem / Why
Verified against the installed Omarchy shell and the Hyprland 0.56.2 Lua stubs (`/usr/share/hypr/stubs/hl.meta.lua`):
- `hl.unbind(trigger)` removes every bind on that key, including the user's own binds (see `/usr/share/omarchy/default/hypr/bindings/utilities.lua:45-80`, which keeps `hl.bind` handles and calls `:unbind()` instead).
- The key sequence (modifier down, key, modifier up) runs on 40 ms timers. A second trigger, or a focus change mid-sequence, can leave a modifier held down.
- Only `class` is matched; `initial_class` is ignored.
- `pcall(require, ...)` hides generated-file errors, so `apply.sh` cannot detect a broken file.
- `Panel.qml` builds the script path without `decodeURIComponent`, and calls `updateEntryInline` without a `typeof` guard (stock plugins use both).
- Escape while the Dropdown popup is open may close the whole panel. `customTriggerField` does not handle Escape.
- Trigger modifiers are not normalized to uppercase, so duplicate detection misses `super + mouse:275` vs `SUPER + mouse:275`.
- There are no tests.

## Scope
`Model.js`, `Panel.qml`, `apply.sh`, `README.md`, and a new `tests/` directory. No new features.

## Constraints
- UI strings and the README stay in Spanish; code identifiers and comments stay in English.
- `Model.js` must keep `.pragma library` (QML). Tests load it through `node:vm` with that line stripped.
- Keep the existing `pcall(require, "hypr.albion-binds")` loader line, so no migration is needed for current installs.
- Plugins have no remove hook (verified), so cleanup stays documented in the README.

## TDD
- Mode: strict, ON (source: session configuration).
- Runner: `node --test tests/`
- The Lua runtime tests run the generated Lua under `lua` (5.5) with a mocked `hl` table, and are spawned from node.

## Tasks
- [x] T1: Test harness and baseline tests for `Model.js` and the generated Lua. Route: delegated writer (2+ non-trivial files).
- [ ] T2: Lua runtime fixes: keep bind handles, add a busy guard, release held modifiers on focus loss, match `initial_class`. Route: same writer.
- [ ] T3: `apply.sh`: validate the generated Lua with `luac -p` when available, before writing. Route: same writer.
- [ ] T4: `Panel.qml` hardening: `decodeURIComponent`, the `typeof` guard, Dropdown `popupOpen` in `blocked`, Escape on `customTriggerField`. `Model.js`: uppercase trigger modifiers. Route: same writer.
- [ ] T5: README: explain how things work now and how to clean up when uninstalling. Route: same writer.

## Acceptance criteria
- `node --test tests/` passes.
- The generated Lua compiles with `luac -p` and, against the mocked `hl`:
  - binds only while Albion is focused;
  - unbinds with handles and never calls `hl.unbind`;
  - leaves no modifier held down after focus loss.

## Delivery
`single-pr` on branch `refactor/polish`. One work-unit commit per task. RDD is off (global), so there is no native review.

## Progress / evidence
- T1: test harness (node:test, vm loader for Model.js, mocked-`hl` Lua runtime tests) and baseline tests. Baseline tests describe existing behavior, so no RED phase; first run had 1 failure from my own invalid fixture ("bad+" is valid), fixed. GREEN: 23/23. Node 26 rejects the directory argument (`node --test tests/` -> MODULE_NOT_FOUND), so `package.json` adds `npm test` = `node --test "tests/**/*.test.mjs"`.
_(updated per task)_
