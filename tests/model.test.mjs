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
