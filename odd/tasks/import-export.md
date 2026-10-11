# Import / export binds

## Objective
Add Export and Import buttons so binds can be moved between PCs through a JSON file.

## Problem / Why
Binds live only in this PC's `~/.config/omarchy/shell.json`. The user wants to bring the same binds to their other PCs.

## Decisions
- Transport: a JSON file at `~/albion-binds.json` (user choice). It can be carried over USB, Syncthing, Drive or git.
- File format: `{ "app": "albion-binds", "version": 1, "enabled": <bool>, "binds": [{ "trigger", "combo", "enabled" }] }`, pretty-printed with a trailing newline.
- Import **replaces** the current binds and the master switch with the file's contents, after `sanitizeBinds`.
  - Invalid JSON, a wrong shape, or a file with no valid binds: show an error and keep the current state.
  - Invalid entries are dropped, and the message reports how many were skipped.
- File I/O uses Quickshell `FileView` with `atomicWrites`, plus `Quickshell.env("HOME")`. This follows the pattern in `/usr/share/omarchy/shell/shell.qml:113-138`.

## Scope
`Model.js` (pure functions `exportBinds` and `parseImport`), `Panel.qml` (new "RESPALDO" section with two buttons and a status line), tests, and the README.

## TDD
- Strict, ON. Runner: `npm test`.

## Tasks
- [x] T1: `Model.exportBinds(binds, enabled)` and `Model.parseImport(text)`, test-first. Route: delegated writer (2+ non-trivial files).
- [ ] T2: `Panel.qml` "RESPALDO" section with Exportar/Importar wired to a FileView, plus success and error feedback. Route: same writer.
- [ ] T3: README section "Llevar tus atajos a otra PC". Route: same writer.

## Acceptance criteria
- An export/import round trip gives back the same binds and the same enabled state.
- Malformed input returns an error message and changes nothing.
- `npm test` is green.

## Delivery
`single-pr` on branch `feat/import-export`. RDD is off.

## Progress / evidence
- T1: RED observed (10 new tests failing: `Model.parseImport is not a function`, 35 pass / 10 fail). GREEN after implementing `exportBinds` and `parseImport` in Model.js: 45 pass / 0 fail via `npm test`. Route: delegated writer (2+ files). Commit: see T2 entry.
