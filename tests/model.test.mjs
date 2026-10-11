import { test } from "node:test"
import assert from "node:assert/strict"
import { loadModel, plain } from "./helpers/load-model.mjs"

const Model = loadModel()

test("parseCombo: single letter is uppercased", () => {
  assert.deepEqual(plain(Model.parseCombo("m")), { mods: [], key: "M", text: "M" })
})

test("parseCombo: spaces and case are normalized", () => {
  assert.deepEqual(plain(Model.parseCombo("shift + n")), { mods: ["SHIFT"], key: "N", text: "SHIFT+N" })
})

test("parseCombo: modifier aliases map to canonical names", () => {
  assert.deepEqual(plain(Model.parseCombo("CONTROL+a")).mods, ["CTRL"])
  assert.deepEqual(plain(Model.parseCombo("WIN+a")).mods, ["SUPER"])
  assert.deepEqual(plain(Model.parseCombo("META+a")).mods, ["SUPER"])
})

test("parseCombo: duplicate modifiers are rejected (also through aliases)", () => {
  assert.equal(Model.parseCombo("SHIFT+SHIFT+N"), null)
  assert.equal(Model.parseCombo("WIN+SUPER+N"), null)
})

test("parseCombo: unknown modifier, invalid key and empty input are rejected", () => {
  assert.equal(Model.parseCombo("FOO+N"), null)
  assert.equal(Model.parseCombo("SHIFT+N!"), null)
  assert.equal(Model.parseCombo(""), null)
  assert.equal(Model.parseCombo(null), null)
})

test("parseCombo: multi-character keys keep their case", () => {
  assert.equal(Model.parseCombo("ctrl+F5").key, "F5")
})

test("normalizeTrigger: accepts plain keys and buttons", () => {
  assert.equal(Model.normalizeTrigger("mouse:275"), "mouse:275")
  assert.equal(Model.normalizeTrigger("  F5 "), "F5")
})

test("normalizeTrigger: normalizes spacing around plus", () => {
  assert.equal(Model.normalizeTrigger("SUPER+mouse:275"), "SUPER + mouse:275")
  assert.equal(Model.normalizeTrigger("SUPER   +   x"), "")
})

test("normalizeTrigger: uppercases modifiers and keeps the last part as-is", () => {
  assert.equal(Model.normalizeTrigger("super+mouse:275"), "SUPER + mouse:275")
  assert.equal(Model.normalizeTrigger("ctrl + alt+F5"), "CTRL + ALT + F5")
  assert.equal(Model.normalizeTrigger("super + mouse:275"), Model.normalizeTrigger("SUPER+mouse:275"))
})

test("normalizeTrigger: rejects invalid input", () => {
  assert.equal(Model.normalizeTrigger(""), "")
  assert.equal(Model.normalizeTrigger("a b"), "")
  assert.equal(Model.normalizeTrigger('x"y'), "")
  assert.equal(Model.normalizeTrigger(undefined), "")
})

test("sanitizeBinds: drops invalid entries and defaults enabled to true", () => {
  const out = plain(Model.sanitizeBinds([
    { trigger: "mouse:275", combo: "shift+n" },
    { trigger: "", combo: "N" },
    { trigger: "F5", combo: "FOO+N" },
    null,
    { trigger: "mouse:276", combo: "M", enabled: false }
  ]))
  assert.deepEqual(out, [
    { trigger: "mouse:275", combo: "SHIFT+N", enabled: true },
    { trigger: "mouse:276", combo: "M", enabled: false }
  ])
})

test("sanitizeBinds: non-array input yields an empty list", () => {
  assert.deepEqual(plain(Model.sanitizeBinds(undefined)), [])
  assert.deepEqual(plain(Model.sanitizeBinds({})), [])
})

test("triggerLabel: known presets get a label, others pass through", () => {
  assert.equal(Model.triggerLabel("mouse:275"), "Botón lateral abajo")
  assert.equal(Model.triggerLabel("F9"), "F9")
})

test("luaString: escapes backslashes and quotes", () => {
  assert.equal(Model.luaString('a"b\\c'), '"a\\"b\\\\c"')
})

test("generateLua: master switch off produces no bind rows", () => {
  const lua = Model.generateLua(Model.DEFAULT_BINDS, false)
  assert.doesNotMatch(lua, /trigger = /)
})

test("generateLua: disabled binds are skipped", () => {
  const lua = Model.generateLua([{ trigger: "mouse:275", combo: "N", enabled: false }], true)
  assert.doesNotMatch(lua, /trigger = /)
})

test("generateLua: enabled bind becomes a row", () => {
  const lua = Model.generateLua([{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }], true)
  assert.match(lua, /\{ trigger = "mouse:275", mods = \{ "SHIFT" \}, key = "N", label = "SHIFT\+N" \},/)
})

test("generateLua: keeps the Albion class constant", () => {
  assert.match(Model.generateLua([], true), /local ALBION_CLASS = "Albion-Online"/)
})

test("exportBinds: writes app, version, enabled and sanitized binds, pretty-printed", () => {
  const text = Model.exportBinds([{ trigger: "mouse:275", combo: "shift + n", enabled: true }], false)
  assert.ok(text.endsWith("}\n"))
  assert.deepEqual(JSON.parse(text), {
    app: "albion-binds",
    version: 1,
    enabled: false,
    binds: [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }]
  })
  assert.ok(text.includes("\n  \"app\""))
})

test("exportBinds: enabled defaults to true unless explicitly false", () => {
  assert.equal(JSON.parse(Model.exportBinds([], undefined)).enabled, true)
})

test("parseImport: round trip returns the sanitized binds and enabled state", () => {
  const binds = [
    { trigger: "mouse:275", combo: "SHIFT+N", enabled: true },
    { trigger: "F5", combo: "CTRL+1", enabled: false }
  ]
  const r = plain(Model.parseImport(Model.exportBinds(binds, false)))
  assert.deepEqual(r, { ok: true, binds, enabled: false, skipped: 0 })
})

test("parseImport: invalid JSON is an error", () => {
  const r = Model.parseImport("{nope")
  assert.equal(r.ok, false)
  assert.equal(r.error, "El archivo no es JSON válido.")
})

test("parseImport: wrong app and newer version are errors", () => {
  assert.equal(Model.parseImport(JSON.stringify({ app: "other", binds: [] })).ok, false)
  const r = Model.parseImport(JSON.stringify({ app: "albion-binds", version: 2, binds: [] }))
  assert.equal(r.ok, false)
  assert.match(r.error, /versión/)
})

test("parseImport: object without a binds array is an error", () => {
  assert.equal(Model.parseImport(JSON.stringify({ app: "albion-binds" })).ok, false)
})

test("parseImport: accepts a bare array and defaults enabled to true", () => {
  const r = plain(Model.parseImport(JSON.stringify([{ trigger: "mouse:276", combo: "m" }])))
  assert.deepEqual(r, { ok: true, binds: [{ trigger: "mouse:276", combo: "M", enabled: true }], enabled: true, skipped: 0 })
})

test("parseImport: counts invalid and duplicate-trigger entries as skipped, keeping the first", () => {
  const r = plain(Model.parseImport(JSON.stringify({
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
  assert.equal(Model.parseImport(JSON.stringify({ binds: [{ trigger: "!", combo: "" }] })).ok, false)
  const r = plain(Model.parseImport(JSON.stringify({ binds: [] })))
  assert.deepEqual(r, { ok: true, binds: [], enabled: true, skipped: 0 })
})

test("parseImport: non-object and non-array JSON is an error", () => {
  assert.equal(Model.parseImport("42").ok, false)
  assert.equal(Model.parseImport("null").ok, false)
  assert.equal(Model.parseImport("\"x\"").ok, false)
})
