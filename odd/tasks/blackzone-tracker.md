# Phase 3: Black zone profit tracker (Zona negra)

## Objective
Turn the Zona negra tab into a profit tracker that compares the silver lost in deaths (sets valued per piece at market prices) with the silver gained from chests.

## Problem / Why
The user wants to know whether black zone runs pay off. Albion exposes neither deaths nor loot, so both are logged manually. Set value should follow the market instead of a fixed number (user decision, 2026-10-11).

## Decisions
- Storage: `blackzone.sets`, `blackzone.events` in `data.json` (DataStore, live reload already in place). Version stays 1. Malformed entries are dropped on parse, injected sanitizer like `Farm.sanitizeFarm`.
- **Set:**
  ```
  { id, name, pieces: [{ slot, base, tier, enchant, quality, quantity }] }
  ```
  - Slots: head, armor, shoes, mainhand, offhand, cape, bag, mount, plus consumables `potion` and `food`.
  - Scope change (2026-10-11, user decision): consumables are IN scope. Their pieces carry `quantity` (integer >= 1, default 1; they are stacks); quality does not apply (stored as 1, selector hidden). A piece's death value is price x quantity. Gear pieces keep quantity 1.
  - Item id = `T<tier>_<base>` plus `@<enchant>` when enchant > 0. The API quality is 1..5.
- **Events:**
  - Death: `{ id, type: "death", setId, at, value, setName, partial, pieces: [{ itemId, quality, quantity, price|null }] }`. Prices are a SNAPSHOT at log time, so later price changes never rewrite history. The user can edit the value before saving.
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
- [x] T1: Gear catalog generator script and generated catalog (tests on the pure transform with a small fixture: slot mapping, tier-adjective stripping, dedupe). Route: delegated writer.
- [x] T2: `blackzone/Blackzone.js`, pure and test-first:
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

### T1 (writer) - 5d36a45
- `scripts/gear-catalog.mjs` (pure transform) + `scripts/build-gear-catalog.mjs`; regenerate with `npm run build:catalog [path/to/items.json]` (downloads the dump to the OS temp folder when no path is given; never committed).
- RED: `tests/gear-catalog.test.mjs` failed to load (module missing). GREEN: 136/136 total after the module (7 new tests).
- Catalog: 362 entries, 35,170 bytes. Slots: mainhand 150, mount 40, armor 34, head 34, shoes 34, food 20, offhand 18, cape 15, potion 15, bag 2.
- Tier grades (ES-ES, stripped from gear names): T1 principiante, T2 novato, T3 obrero, T4 iniciado, T5 experto, T6 maestro, T7 gran maestro, T8 anciano. Consumables use other names per tier: potions end in "menor"/"mayor" (stripped); meals change ingredient per tier (common word prefix kept, e.g. "Sopa", or "... asado").
- Exclusions: MOUNTUPGRADE, `_SKIN`, `CAPEITEM_*_BP` (insignias), decorative `CAPE_*` (undead/keeper/morgana, arena banner), `ARTEFACT`, `PROTOTYPE` (no names), `_XMAS`, siege items, `SPECIAL_FOOD`, UNIQUE_/untiered ids, anything without ES/EN name.

### T2 (writer) - ddbdb79
- RED: `tests/blackzone.test.mjs` failed to load (module missing; 136 pass + 1 failing file), then Prices/Storage additions failed 4 of 162. GREEN: `npm test` 162/162.
- Removed set decision: deleting a set keeps its death events; every death stores `setName` (snapshot), so history, totals and per-set losses still show the old name. Renaming a set does not rewrite past deaths.
- `Prices.buildUrl(ids, city, server, qualities)` (optional list, default `[1]`) and `Prices.parseQualityPrices` (keys `itemId:quality`) added; farm callers unchanged.
- `Storage.parseData/reloadOutcome` take an injected `sanitizeBlackzone`; `DataStore.qml` passes `Blackzone.sanitizeBlackzone`.
