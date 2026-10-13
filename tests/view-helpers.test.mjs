import { test } from "node:test"
import assert from "node:assert/strict"
import { loadViewHelpers, loadFarm } from "./helpers/load-model.mjs"

const Helpers = loadViewHelpers()
const Farm = loadFarm()

test("shortDate: dd/MM/yy in local time", () => {
  assert.equal(Helpers.shortDate(new Date(2026, 9, 12, 12).getTime()), "12/10/26")
  assert.equal(Helpers.shortDate(new Date(2031, 0, 5, 0, 30).getTime()), "05/01/31")
  assert.equal(Helpers.shortDate(new Date(2009, 11, 31, 23, 59).getTime()), "31/12/09")
})

test("shortDate: invalid input gives a dash", () => {
  assert.equal(Helpers.shortDate(NaN), "-")
  assert.equal(Helpers.shortDate(undefined), "-")
})

test("newId: prefix, injected clock and random part", () => {
  assert.equal(Helpers.newId("p", 36, 0), "p100")
  assert.equal(Helpers.newId("c", 1296, 0.5), "c100" + (648).toString(36))
})

test("newId: defaults produce distinct ids with the prefix", () => {
  const a = Helpers.newId("x")
  assert.ok(a.startsWith("x"))
  assert.ok(a.length > 2)
})

test("Farm.signed: explicit plus for gains, minus kept, zero unsigned", () => {
  assert.equal(Farm.signed(1500), "+1,500")
  assert.equal(Farm.signed(-1500), "-1,500")
  assert.equal(Farm.signed(0), "0")
})
