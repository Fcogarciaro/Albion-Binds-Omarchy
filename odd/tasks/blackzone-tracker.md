# Phase 3: Black zone profit tracker (Zona negra)

## Objective
Turn the Zona negra tab into a profit tracker that compares the silver lost in deaths (sets valued per piece at market prices) with the silver gained from chests.

## Problem / Why
The user wants to know whether black zone runs pay off. Albion exposes neither deaths nor loot, so both are logged manually. Set value should follow the market instead of a fixed number (user decision, 2026-10-11).

## Decisions
- Storage: `blackzone.sets`, `blackzone.events` in `data.json` (DataStore, live reload already in place). Version stays 1. Malformed entries are dropped on parse, injected sanitizer like `Farm.sanitizeFarm`.
- **Set:**
  ```
  { id, name, pieces: [{ slot, base, tier, enchant, quality }] }
  ```
  - Slots: head, armor, shoes, mainhand, offhand, cape, bag, mount.
  - Consumables are out of scope.
  - Item id = `T<tier>_<base>` plus `@<enchant>` when enchant > 0. The API quality is 1..5.
- **Events:**
  - Death: `{ id, type: "death", setId, at, value, pieces: [{ itemId, quality, price|null }] }`. Prices are a SNAPSHOT at log time, so later price changes never rewrite history. The user can edit the value before saving.
  - Loot: `{ id, type: "loot", at, value, note }`. The value is silver typed by the user.
  - Delete with a two-tap confirm, as in Cultivos.
- **Profit** = Σ loot.value − Σ death.value, shown in total and per set. Death count and a loot/death ratio are nice-to-have.
- **Prices:**
  - Reuse `farm/Prices.js` (`buildUrl` / `parsePrices`), extended test-first if quality support is needed.
  - City selector, west server, Process+curl.
  - Missing price means the piece shows "sin precio" and the death is marked partial. The user can type the value.
- **Gear catalog:** generated from ao-bin-dumps `formatted/items.json` (verified 2026-10-11: 12237 items, `LocalizedNames["ES-ES"]` present, e.g. `T6_HEAD_PLATE_SET1@2` = "Casco de soldado del maestro"; 7110 T4-T8 gear entries).
  - A committed generator script writes a compact JS catalog of base types: `{ base, slot, nameEs, tiers }`, with Spanish names without the tier adjective.
  - The generated file is committed. The plugin never downloads the catalog at runtime.
- **UI:** must fit the ~380px bar panel.
  - Set editor: add a piece with slot, search box filtered by slot, tier, enchant and quality.
  - Death log: pick a set, fetch prices, review, then save.
  - Loot log: value plus an optional note.
  - Summary and history.
  - Spanish copy, English code.

## TDD
- Strict, ON (session config). Runner: `npm test`.
- `qmllint` with the `qs` symlink, as in farm-log T3.

## Tasks
- [ ] T1: Gear catalog generator script and generated catalog (tests on the pure transform with a small fixture: slot mapping, tier-adjective stripping, dedupe). Route: delegated writer.
- [ ] T2: `blackzone/Blackzone.js`, pure and test-first:
  - Sanitize.
  - Set CRUD and piece item ids.
  - `logDeath` (with snapshot), `logLoot`, removal.
  - Totals.
  - Storage wiring.
  - Route: same writer.
- [ ] T3: `blackzone/BlackzoneView.qml`: sets editor, death and loot logging with price fetch, summary and history, deletes. Route: same writer.
- [ ] T4: README "Zona negra" section. Route: same writer.

## Acceptance criteria
- `npm test` green.
- No new qmllint categories.
- Existing data files load unchanged.
- The catalog generator is reproducible: a documented command regenerates it.

## Delivery
`single-pr` on branch `feat/blackzone-tracker`. RDD is off (global).

## Progress / evidence
