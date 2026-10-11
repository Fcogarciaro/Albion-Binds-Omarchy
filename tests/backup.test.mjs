import { test } from "node:test"
import assert from "node:assert/strict"
import { loadBinds, loadBackup, plain } from "./helpers/load-model.mjs"

const { sanitizeBinds } = loadBinds()
const raw = loadBackup()
const Backup = {
  exportBinds: (binds, enabled) => raw.exportBinds(binds, enabled, sanitizeBinds),
  parseImport: (text) => raw.parseImport(text, sanitizeBinds)
}

test("exportBinds: writes app, version, enabled and sanitized binds, pretty-printed", () => {
  const text = Backup.exportBinds([{ trigger: "mouse:275", combo: "shift + n", enabled: true }], false)
  assert.ok(text.endsWith("}\n"))
  assert.deepEqual(JSON.parse(text), {
    app: "albion-companion",
    version: 1,
    enabled: false,
    binds: [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }]
  })
  assert.ok(text.includes("\n  \"app\""))
})

test("exportBinds: enabled defaults to true unless explicitly false", () => {
  assert.equal(JSON.parse(Backup.exportBinds([], undefined)).enabled, true)
})

test("parseImport: round trip returns the sanitized binds and enabled state", () => {
  const binds = [
    { trigger: "mouse:275", combo: "SHIFT+N", enabled: true },
    { trigger: "F5", combo: "CTRL+1", enabled: false }
  ]
  const r = plain(Backup.parseImport(Backup.exportBinds(binds, false)))
  assert.deepEqual(r, { ok: true, binds, enabled: false, skipped: 0 })
})

test("parseImport: invalid JSON is an error", () => {
  const r = Backup.parseImport("{nope")
  assert.equal(r.ok, false)
  assert.equal(r.error, "El archivo no es JSON válido.")
})

test("parseImport: wrong app and newer version are errors", () => {
  assert.equal(Backup.parseImport(JSON.stringify({ app: "other", binds: [] })).ok, false)
  const r = Backup.parseImport(JSON.stringify({ app: "albion-companion", version: 2, binds: [] }))
  assert.equal(r.ok, false)
  assert.match(r.error, /versión/)
})

test("parseImport: object without a binds array is an error", () => {
  assert.equal(Backup.parseImport(JSON.stringify({ app: "albion-companion" })).ok, false)
})

test("parseImport: accepts a bare array and defaults enabled to true", () => {
  const r = plain(Backup.parseImport(JSON.stringify([{ trigger: "mouse:276", combo: "m" }])))
  assert.deepEqual(r, { ok: true, binds: [{ trigger: "mouse:276", combo: "M", enabled: true }], enabled: true, skipped: 0 })
})

test("parseImport: counts invalid and duplicate-trigger entries as skipped, keeping the first", () => {
  const r = plain(Backup.parseImport(JSON.stringify({
    binds: [
      { trigger: "mouse:275", combo: "SHIFT+N" },
      { trigger: "mouse:275", combo: "M" },
      { trigger: "bad trigger!", combo: "M" },
      { trigger: "F5", combo: "" }
    ]
  })))
  assert.equal(r.ok, true)
  assert.deepEqual(r.binds, [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }])
  assert.equal(r.skipped, 3)
})

test("parseImport: entries present but none valid is an error; empty list is ok", () => {
  assert.equal(Backup.parseImport(JSON.stringify({ binds: [{ trigger: "!", combo: "" }] })).ok, false)
  const r = plain(Backup.parseImport(JSON.stringify({ binds: [] })))
  assert.deepEqual(r, { ok: true, binds: [], enabled: true, skipped: 0 })
})

test("parseImport: non-object and non-array JSON is an error", () => {
  assert.equal(Backup.parseImport("42").ok, false)
  assert.equal(Backup.parseImport("null").ok, false)
  assert.equal(Backup.parseImport("\"x\"").ok, false)
})

test("parseImport: accepts legacy albion-binds files", () => {
  const r = plain(Backup.parseImport(JSON.stringify({
    app: "albion-binds", version: 1, enabled: false,
    binds: [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }]
  })))
  assert.equal(r.ok, true)
  assert.equal(r.enabled, false)
  assert.deepEqual(r.binds, [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }])
})

test("parseImport: a newer legacy version is still rejected", () => {
  assert.equal(Backup.parseImport(JSON.stringify({ app: "albion-binds", version: 2, binds: [] })).ok, false)
})

test("exportBinds: never writes the legacy app name", () => {
  assert.notEqual(JSON.parse(Backup.exportBinds([], true)).app, "albion-binds")
})
