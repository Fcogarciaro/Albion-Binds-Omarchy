import { test } from "node:test"
import assert from "node:assert/strict"
import { loadStorage, plain } from "./helpers/load-model.mjs"

const Storage = loadStorage()

const EMPTY = { version: 1, farm: { plots: [], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [] } }

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
  const doc = { version: 1, farm: { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.04, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [{ t: 1 }] } }
  const r = plain(Storage.parseData(JSON.stringify(doc)))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, doc)
})

test("parseData: missing sections are filled with defaults", () => {
  const r = plain(Storage.parseData(JSON.stringify({ version: 1, farm: { plots: [{ id: "a" }] } })))
  assert.equal(r.ok, true)
  assert.deepEqual(r.data, { version: 1, farm: { plots: [{ id: "a" }], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [] } })
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
  assert.deepEqual(r.data, { version: 1, farm: { plots: [], cycles: [], settings: { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 } }, blackzone: { sets: [], events: [1] } })
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
