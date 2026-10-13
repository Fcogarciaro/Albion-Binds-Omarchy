import { test } from "node:test"
import assert from "node:assert/strict"
import { loadPrices, plain } from "./helpers/load-model.mjs"

const Prices = loadPrices()

test("buildUrl: default west server, encoded city, quality 1", () => {
  assert.equal(
    Prices.buildUrl(["T4_TURNIP", "T4_FARM_TURNIP_SEED"], "Fort Sterling"),
    "https://west.albion-online-data.com/api/v2/stats/prices/T4_TURNIP,T4_FARM_TURNIP_SEED?locations=Fort%20Sterling&qualities=1"
  )
})

test("buildUrl: other servers; unknown server falls back to west", () => {
  assert.match(Prices.buildUrl(["T1_CARROT"], "Lymhurst", "east"), /^https:\/\/east\.albion-online-data\.com\//)
  assert.match(Prices.buildUrl(["T1_CARROT"], "Lymhurst", "europe"), /^https:\/\/europe\.albion-online-data\.com\//)
  assert.match(Prices.buildUrl(["T1_CARROT"], "Lymhurst", "evil.com/x"), /^https:\/\/west\.albion-online-data\.com\//)
})

test("buildUrl: drops unsafe item ids", () => {
  const url = Prices.buildUrl(["T1_CARROT", "a/b?c", ""], "Martlock")
  assert.match(url, /prices\/T1_CARROT\?/)
})

test("CITIES: royal cities as dropdown options", () => {
  const cities = plain(Prices.CITIES)
  assert.ok(cities.length >= 6)
  for (const c of cities) assert.deepEqual(Object.keys(c).sort(), ["label", "value"])
  assert.ok(cities.some((c) => c.value === "Fort Sterling"))
})

const sample = JSON.stringify([
  { item_id: "T4_TURNIP", city: "Lymhurst", quality: 1, sell_price_min: 420 },
  { item_id: "T4_FARM_TURNIP_SEED", city: "Lymhurst", quality: 1, sell_price_min: 0 },
  { item_id: "T4_TURNIP", city: "Martlock", quality: 1, sell_price_min: 999 }
])

test("parsePrices: picks the city, maps 0 to null", () => {
  const r = plain(Prices.parsePrices(sample, "Lymhurst"))
  assert.equal(r.ok, true)
  assert.deepEqual(r.prices, { T4_TURNIP: 420, T4_FARM_TURNIP_SEED: null })
})

test("parsePrices: requested ids missing from the response are null", () => {
  const r = plain(Prices.parsePrices(sample, "Lymhurst", ["T4_TURNIP", "T6_POTATO"]))
  assert.deepEqual(r.prices, { T4_TURNIP: 420, T4_FARM_TURNIP_SEED: null, T6_POTATO: null })
})

test("parsePrices: keeps the lowest non-zero price when a city repeats an item", () => {
  const text = JSON.stringify([
    { item_id: "T4_TURNIP", city: "Lymhurst", sell_price_min: 500 },
    { item_id: "T4_TURNIP", city: "Lymhurst", sell_price_min: 450 },
    { item_id: "T4_TURNIP", city: "Lymhurst", sell_price_min: 0 }
  ])
  assert.equal(Prices.parsePrices(text, "Lymhurst").prices.T4_TURNIP, 450)
})

test("parsePrices: malformed input is an error result", () => {
  for (const text of ["", "{nope", "{}", "42", "null", "<html>502</html>"]) {
    const r = Prices.parsePrices(text, "Lymhurst")
    assert.equal(r.ok, false, text)
    assert.equal(typeof r.error, "string")
  }
})

test("parsePrices: ignores junk entries and bad prices", () => {
  const text = JSON.stringify([null, 3, { item_id: 5 }, { item_id: "T1_CARROT", city: "Lymhurst", sell_price_min: "x" }, { item_id: "T2_BEAN", city: "Lymhurst", sell_price_min: -4 }])
  const r = plain(Prices.parsePrices(text, "Lymhurst"))
  assert.equal(r.ok, true)
  assert.deepEqual(r.prices, { T1_CARROT: null, T2_BEAN: null })
})

test("buildUrl: optional qualities list (default stays quality 1)", () => {
  assert.match(Prices.buildUrl(["T4_2H_BOW"], "Lymhurst", "west", [1, 2, 3, 4, 5]), /&qualities=1,2,3,4,5$/)
  assert.match(Prices.buildUrl(["T4_2H_BOW"], "Lymhurst", "west", [9, "x", 2]), /&qualities=2$/)
  assert.match(Prices.buildUrl(["T4_2H_BOW"], "Lymhurst", "west", []), /&qualities=1$/)
})

test("parseQualityPrices: keys are itemId:quality, missing wanted keys are null", () => {
  const text = JSON.stringify([
    { item_id: "T4_2H_BOW", city: "Lymhurst", quality: 1, sell_price_min: 900 },
    { item_id: "T4_2H_BOW", city: "Lymhurst", quality: 3, sell_price_min: 1500 },
    { item_id: "T4_2H_BOW", city: "Lymhurst", quality: 3, sell_price_min: 1200 },
    { item_id: "T4_2H_BOW", city: "Martlock", quality: 2, sell_price_min: 5 },
    { item_id: "T5_POTION_HEAL", city: "Lymhurst", quality: 1, sell_price_min: 0 }
  ])
  const r = plain(Prices.parseQualityPrices(text, "Lymhurst", ["T4_2H_BOW:1", "T4_2H_BOW:2", "T5_POTION_HEAL:1"]))
  assert.equal(r.ok, true)
  assert.deepEqual(r.prices, { "T4_2H_BOW:1": 900, "T4_2H_BOW:3": 1200, "T4_2H_BOW:2": null, "T5_POTION_HEAL:1": null })
  assert.equal(Prices.parseQualityPrices("{nope", "Lymhurst").ok, false)
})

test("curlArgs: compressed, quiet-but-showing-errors, status code appended", () => {
  const args = Prices.curlArgs("https://x/y", 8)
  assert.equal(args[0], "curl")
  assert.ok(args.includes("--compressed"))
  assert.equal(args[args.indexOf("--max-time") + 1], "8")
  assert.equal(args[args.indexOf("-w") + 1], "\n%{http_code}")
  assert.equal(args[args.length - 1], "https://x/y")
  assert.ok(!args.includes("-f"))
})

test("checkResponse: splits body and status, flags HTTP failures", () => {
  assert.deepEqual(plain(Prices.checkResponse('[{"a":1}]\n200', "generic")), { ok: true, body: '[{"a":1}]' })
  const throttled = plain(Prices.checkResponse("Throttled, be nice\n429", "generic"))
  assert.equal(throttled.ok, false)
  assert.equal(throttled.error, "El mercado limitó las consultas, intenta en un minuto.")
  assert.deepEqual(plain(Prices.checkResponse("oops\n500", "generic")), { ok: false, error: "generic" })
  assert.deepEqual(plain(Prices.checkResponse("\n000", "generic")), { ok: false, error: "generic" })
  assert.deepEqual(plain(Prices.checkResponse("", "generic")), { ok: false, error: "generic" })
  assert.deepEqual(plain(Prices.checkResponse("no status line", "generic")), { ok: false, error: "generic" })
})

test("sameRequest: equal only when every field matches", () => {
  const a = { city: "Lymhurst", server: "west", plotId: "p1", mode: "plant", itemId: "T1" }
  assert.equal(Prices.sameRequest(a, Object.assign({}, a)), true)
  for (const patch of [{ city: "Martlock" }, { server: "east" }, { plotId: "p2" }, { mode: "harvest" }, { itemId: "T2" }]) {
    assert.equal(Prices.sameRequest(a, Object.assign({}, a, patch)), false, JSON.stringify(patch))
  }
  assert.equal(Prices.sameRequest(a, null), false)
  assert.equal(Prices.sameRequest(null, null), false)
  assert.equal(Prices.sameRequest(a, { city: "Lymhurst" }), false)
})
