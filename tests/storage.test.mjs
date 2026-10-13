import { test } from "node:test"
import assert from "node:assert/strict"
import { loadStorage, plain } from "./helpers/load-model.mjs"

const Storage = loadStorage()

const EMPTY = { version: 1, farm: { plots: [], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [] }, ui: { city: "Lymhurst", deathSetId: "", expenseNote: "", tab: "binds" } }

test("defaultData: versioned empty document", () => {
  assert.equal(Storage.DATA_VERSION, 1)
  assert.deepEqual(plain(Storage.defaultData()), EMPTY)
})

test("defaultData: returns a fresh object each time", () => {
  const a = Storage.defaultData()
  a.farm.plots.push({ id: 1 })
  assert.deepEqual(plain(Storage.defaultData()), EMPTY)
})

test("parseData: round trip of a valid document", () => {
  const doc = { version: 1, farm: { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.04, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [{ t: 1 }] }, ui: { city: "Bridgewatch", deathSetId: "s1", expenseNote: "Portal SAFE", tab: "farm" } }
  const r = plain(Storage.parseData(JSON.stringify(doc)))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, doc)
})

test("parseData: missing sections are filled with defaults", () => {
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, farm: { plots: [{ id: "a" }] } })))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, { version: 1, farm: { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [] }, ui: { city: "Lymhurst", deathSetId: "", expenseNote: "", tab: "binds" } })
})

test("parseData: an empty object gets the full default document", () => {
  const r = plain(Storage.parseData("{}"))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, EMPTY)
})

test("parseData: invalid JSON is an error", () => {
  const r = plain(Storage.parseData("{nope"))
  assert.equal(r.ok, false)
  assert.equal(typeof r.error, "string")
})

test("parseData: non-object JSON is an error", () => {
  for (const text of ["42", "null", "[]", "\"x\""]) assert.equal(Storage.parseData(text).ok, false, text)
})

test("parseData: a newer version is an error", () => {
  assert.equal(Storage.parseData(JSON.stringify({ version: 2 })).ok, false)
})

test("parseData: wrongly typed sections are replaced by defaults", () => {
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, farm: "x", blackzone: { sets: 3, events: [1] } })))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, { version: 1, farm: { plots: [], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [1] }, ui: { city: "Lymhurst", deathSetId: "", expenseNote: "", tab: "binds" } })
})

test("serializeData: pretty-printed with trailing newline, parseable", () => {
  const text = Storage.serializeData(Storage.defaultData())
  assert.ok(text.endsWith("}\n"))
  assert.deepEqual(plain(Storage.parseData(text).data), EMPTY)
})

test("parseData: an existing file with empty farm arrays loads unchanged plus default settings", () => {
  const text = JSON.stringify({ version: 1, farm: { plots: [], cycles: [] }, blackzone: { sets: [], events: [] } })
  assert.deepEqual(plain(Storage.parseData(text).data), EMPTY)
})

test("parseData: invalid tax rates fall back to the default", () => {
  for (const taxRate of ["x", -1, 2, null]) {
    const r = Storage.parseData(JSON.stringify({ farm: { settings: { taxRate } } }))
    assert.equal(r.data.farm.settings.taxRate, 0.065, String(taxRate))
  }
})

test("parseData: an injected farm sanitizer cleans plots and cycles", () => {
  const sanitize = (farm) => ({ plots: farm.plots.slice(0, 1), cycles: [], settings: farm.settings })
  const text = JSON.stringify({ farm: { plots: [{ id: "a" }, { id: "b" }], cycles: [{ id: "c" }], settings: { taxRate: 0.04 } } })
  const r = plain(Storage.parseData(text, sanitize))
  assert.deepEqual(r.data.farm, { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.04, premium: true, focus: true, seedsPerPlot: 9 } })
})

test("reloadOutcome: text identical to our last write is our own echo", () => {
  const text = Storage.serializeData(Storage.defaultData())
  assert.deepEqual(plain(Storage.reloadOutcome(text, text, Storage.defaultData())), { action: "same" })
})

test("reloadOutcome: a different valid file is applied", () => {
  const external = { version: 1, farm: { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.04 } }, blackzone: { sets: [], events: [] } }
  const r = plain(Storage.reloadOutcome(JSON.stringify(external), "", Storage.defaultData()))
  assert.equal(r.action, "apply")
  assert.deepEqual(r.data.farm.plots, [{ id: "a" }])
})

test("reloadOutcome: content equal to the in-memory document is not re-applied", () => {
  const text = JSON.stringify(Storage.defaultData())
  assert.deepEqual(plain(Storage.reloadOutcome(text, "other", Storage.defaultData())), { action: "same" })
})

test("reloadOutcome: unparseable content reports the parse error", () => {
  const r = plain(Storage.reloadOutcome("{nope", "", Storage.defaultData()))
  assert.equal(r.action, "error")
  assert.equal(r.error, "El archivo de datos no es JSON válido.")
})

test("reloadOutcome: honors the injected sanitizer", () => {
  const sanitize = (farm) => ({ plots: [], cycles: [], settings: farm.settings })
  const text = JSON.stringify({ farm: { plots: [{ id: "a" }] } })
  const r = plain(Storage.reloadOutcome(text, "", Storage.defaultData(), sanitize))
  assert.equal(r.action, "same")
})

test("parseData: planner settings load, and invalid ones fall back to defaults", () => {
  const good = Storage.parseData(JSON.stringify({ farm: { settings: { premium: false, focus: false, seedsPerPlot: 6 } } }))
  assert.deepEqual(plain(good.data.farm.settings), { taxRate: 0.065, premium: false, focus: false, seedsPerPlot: 6 })
  for (const seedsPerPlot of ["x", 0, -1, 2.5, 5000, null]) {
    const r = Storage.parseData(JSON.stringify({ farm: { settings: { seedsPerPlot, premium: "no", focus: 0 } } }))
    assert.deepEqual(plain(r.data.farm.settings), { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 }, String(seedsPerPlot))
  }
  assert.equal(good.data.version, 1)
})

test("parseData: an injected blackzone sanitizer cleans sets and events", () => {
  const sanitize = (bz) => ({ sets: bz.sets.filter((x) => x.id), events: [] })
  const text = JSON.stringify({ version: 1, blackzone: { sets: [{ id: "s1" }, {}], events: [{ x: 1 }] } })
  const r = plain(Storage.parseData(text, undefined, sanitize))
  assert.deepEqual(r.data.blackzone, { sets: [{ id: "s1" }], events: [] })
})

test("reloadOutcome: honors the injected blackzone sanitizer", () => {
  const sanitize = () => ({ sets: [], events: [] })
  const current = plain(Storage.defaultData())
  const text = JSON.stringify({ version: 1, blackzone: { sets: [{ id: "bad" }], events: [] } })
  assert.equal(Storage.reloadOutcome(text, "", current, undefined, sanitize).action, "same")
})

test("parseData: ui remembers city, death set and expense note", () => {
  const ui = { city: "Bridgewatch", deathSetId: "s1", expenseNote: "Portal SAFE", tab: "farm" }
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, ui })))
  assert.deepEqual(r.data.ui, ui)
  assert.equal(r.data.version, 1)
})

test("parseData: old files without ui load with the default ui", () => {
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, farm: { plots: [], cycles: [] }, blackzone: { sets: [], events: [] } })))
  assert.deepEqual(r.data.ui, { city: "Lymhurst", deathSetId: "", expenseNote: "", tab: "binds" })
})

test("parseData: invalid ui values fall back field by field, and unknown keys are dropped", () => {
  for (const ui of [null, 5, "x", [], { city: 3, deathSetId: null, expenseNote: {} }, { city: "", deathSetId: "a".repeat(200), expenseNote: "n".repeat(500) }]) {
    const r = plain(Storage.parseData(JSON.stringify({ ui })))
    assert.equal(r.data.ui.city, "Lymhurst", JSON.stringify(ui))
    assert.equal(r.data.ui.deathSetId, "", JSON.stringify(ui))
    assert.ok(r.data.ui.expenseNote.length <= 120, JSON.stringify(ui))
  }
  const r = plain(Storage.parseData(JSON.stringify({ ui: { city: "Martlock", extra: 1, expenseNote: "  Portal  " } })))
  assert.deepEqual(r.data.ui, { city: "Martlock", deathSetId: "", expenseNote: "Portal", tab: "binds" })
})

test("reloadOutcome: a changed ui from another PC is applied", () => {
  const current = plain(Storage.defaultData())
  const text = JSON.stringify({ version: 1, ui: { city: "Thetford" } })
  const r = plain(Storage.reloadOutcome(text, "", current))
  assert.equal(r.action, "apply")
  assert.equal(r.data.ui.city, "Thetford")
})

test("parseData: ui.tab keeps a known tab and falls back to binds otherwise", () => {
  for (const tab of ["binds", "farm", "blackzone"]) {
    const r = plain(Storage.parseData(JSON.stringify({ version: 1, ui: { tab } })))
    assert.equal(r.data.ui.tab, tab)
  }
  for (const tab of ["Farm", "", "window", 3, null, {}, [], "x".repeat(500)]) {
    const r = plain(Storage.parseData(JSON.stringify({ version: 1, ui: { tab } })))
    assert.equal(r.data.ui.tab, "binds", JSON.stringify(tab))
  }
})

test("parseData: files saved before ui.tab load with the default tab and keep version 1", () => {
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, ui: { city: "Martlock", deathSetId: "s1", expenseNote: "Portal" } })))
  assert.equal(r.data.ui.tab, "binds")
  assert.equal(r.data.ui.city, "Martlock")
  assert.equal(r.data.version, 1)
  assert.equal(Storage.DATA_VERSION, 1)
})

test("reloadOutcome: a tab changed from the other surface is applied", () => {
  const current = Storage.defaultData()
  const r = plain(Storage.reloadOutcome(JSON.stringify({ version: 1, ui: { tab: "blackzone" } }), "", current))
  assert.equal(r.action, "apply")
  assert.equal(r.data.ui.tab, "blackzone")
})

test("saveDecision: no write before the first load finishes", () => {
  assert.equal(Storage.saveDecision({ loaded: false, loadBlocked: false }), "queue")
  assert.equal(Storage.saveDecision({ loaded: false, loadBlocked: true }), "queue")
})

test("saveDecision: a parse error on the first load blocks saves", () => {
  assert.equal(Storage.saveDecision({ loaded: true, loadBlocked: true }), "block")
})

test("saveDecision: a healthy loaded store writes", () => {
  assert.equal(Storage.saveDecision({ loaded: true, loadBlocked: false }), "write")
})

test("errorAfterSave: only a save error is cleared by a successful save", () => {
  assert.equal(Storage.errorAfterSave("No pude guardar los datos.", true), "")
  assert.equal(Storage.errorAfterSave("El archivo de datos no es JSON válido.", false), "El archivo de datos no es JSON válido.")
  assert.equal(Storage.errorAfterSave("", false), "")
})
