import { test } from "node:test"
import assert from "node:assert/strict"
import { loadFarm, plain } from "./helpers/load-model.mjs"

const Farm = loadFarm()

const DEFAULT_SETTINGS = { taxRate: 0.065, premium: true, focus: true, seedsPerPlot: 9 }
const empty = () => ({ plots: [], cycles: [], settings: { ...DEFAULT_SETTINGS } })
const ok = (r) => { assert.equal(r.ok, true, r.error); return plain(r.farm) }

function withPlot(name = "Parcela 1", id = "p1") {
  return ok(Farm.addPlot(empty(), name, id))
}

function withOpenCycle() {
  return ok(Farm.plantCycle(withPlot(), { plotId: "p1", crop: "turnip", seedsPlanted: 9, seedPrice: 100, now: 1000, id: "c1" }))
}

test("catalog: T1 to T8 crops with Spanish names, crop and seed ids", () => {
  const crops = plain(Farm.CROPS)
  assert.deepEqual(crops.map((c) => c.tier), [1, 2, 3, 4, 5, 6, 7, 8])
  assert.deepEqual(crops.map((c) => c.key), ["carrot", "bean", "wheat", "turnip", "cabbage", "potato", "corn", "pumpkin"])
  assert.deepEqual(crops.map((c) => c.name), ["Zanahorias", "Frijoles", "Manojo de trigo", "Rábanos", "Coles", "Patatas", "Fardo de maíz", "Calabaza"])
  assert.equal(crops[3].cropId, "T4_TURNIP")
  assert.equal(crops[3].seedId, "T4_FARM_TURNIP_SEED")
  assert.equal(crops[7].cropId, "T8_PUMPKIN")
  assert.equal(crops[7].seedId, "T8_FARM_PUMPKIN_SEED")
})

test("cropByKey: known and unknown keys", () => {
  assert.equal(Farm.cropByKey("potato").cropId, "T6_POTATO")
  assert.equal(Farm.cropByKey("nope"), null)
})

test("addPlot: adds a trimmed plot with the injected id and does not mutate", () => {
  const before = empty()
  const r = Farm.addPlot(before, "  Parcela 1 ", "p1")
  assert.deepEqual(plain(r.farm).plots, [{ id: "p1", name: "Parcela 1" }])
  assert.deepEqual(before.plots, [])
})

test("addPlot: rejects empty and duplicate names (case-insensitive)", () => {
  assert.equal(Farm.addPlot(empty(), "   ", "p1").ok, false)
  const farm = withPlot("Norte")
  const dup = Farm.addPlot(farm, "norte", "p2")
  assert.equal(dup.ok, false)
  assert.match(dup.error, /parcela/i)
})

test("plantCycle: opens a cycle for the plot", () => {
  const farm = withOpenCycle()
  assert.deepEqual(farm.cycles, [{
    id: "c1", plotId: "p1", crop: "turnip", plantedAt: 1000, seedsPlanted: 9, seedPrice: 100,
    harvestedAt: null, cropsHarvested: 0, seedsReturned: 0, cropPrice: 0
  }])
})

test("plantCycle: validates plot, crop, amounts and open cycle", () => {
  const farm = withPlot()
  const base = { plotId: "p1", crop: "turnip", seedsPlanted: 9, seedPrice: 100, now: 1, id: "c1" }
  for (const bad of [
    { plotId: "zzz" }, { crop: "nope" }, { seedsPlanted: 0 }, { seedsPlanted: 1.5 }, { seedsPlanted: -2 },
    { seedPrice: -1 }, { seedPrice: "x" }
  ]) {
    const r = Farm.plantCycle(farm, Object.assign({}, base, bad))
    assert.equal(r.ok, false, JSON.stringify(bad))
    assert.equal(typeof r.error, "string")
  }
  const open = withOpenCycle()
  const again = Farm.plantCycle(open, Object.assign({}, base, { id: "c2" }))
  assert.equal(again.ok, false)
  assert.match(again.error, /abierto|cosech/i)
})

test("harvestCycle: closes the cycle", () => {
  const farm = ok(Farm.harvestCycle(withOpenCycle(), { cycleId: "c1", cropsHarvested: 100, seedsReturned: 10, cropPrice: 500, now: 5000 }))
  const c = farm.cycles[0]
  assert.equal(c.harvestedAt, 5000)
  assert.equal(c.cropsHarvested, 100)
  assert.equal(c.seedsReturned, 10)
  assert.equal(c.cropPrice, 500)
})

test("harvestCycle: validates cycle, state and amounts, allows zero harvest", () => {
  const open = withOpenCycle()
  const base = { cycleId: "c1", cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: 2000 }
  for (const bad of [{ cycleId: "zzz" }, { cropsHarvested: -1 }, { seedsReturned: 1.2 }, { cropPrice: -3 }, { now: 500 }]) {
    assert.equal(Farm.harvestCycle(open, Object.assign({}, base, bad)).ok, false, JSON.stringify(bad))
  }
  assert.equal(Farm.harvestCycle(open, Object.assign({}, base, { cropsHarvested: 0 })).ok, true)
  const closed = ok(Farm.harvestCycle(open, base))
  assert.equal(Farm.harvestCycle(closed, base).ok, false)
})

test("harvestCycle: does not mutate the input", () => {
  const open = withOpenCycle()
  Farm.harvestCycle(open, { cycleId: "c1", cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: 2000 })
  assert.equal(open.cycles[0].harvestedAt, null)
})

test("cycleProfit: crops net of tax plus seed balance", () => {
  const cycle = { seedsPlanted: 9, seedPrice: 100, harvestedAt: 1, cropsHarvested: 100, seedsReturned: 10, cropPrice: 500 }
  // 100 * 500 * 0.935 + (10 - 9) * 100 = 46750 + 100
  assert.equal(Farm.cycleProfit(cycle, 0.065), 46850)
})

test("cycleProfit: negative when seeds are lost, null while open", () => {
  const lost = { seedsPlanted: 9, seedPrice: 100, harvestedAt: 1, cropsHarvested: 0, seedsReturned: 0, cropPrice: 0 }
  assert.equal(Farm.cycleProfit(lost, 0.065), -900)
  assert.equal(Farm.cycleProfit({ seedsPlanted: 9, seedPrice: 100, harvestedAt: null }, 0.065), null)
})

test("cycleProfit: rounds to whole silver", () => {
  const cycle = { seedsPlanted: 1, seedPrice: 0, harvestedAt: 1, cropsHarvested: 1, seedsReturned: 1, cropPrice: 101 }
  assert.equal(Farm.cycleProfit(cycle, 0.065), 94) // 94.4
})

test("totals: overall, per plot and per crop over closed cycles only", () => {
  let farm = withPlot("A", "p1")
  farm = ok(Farm.addPlot(farm, "B", "p2"))
  farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 10, seedPrice: 100, now: 1, id: "c1" }))
  farm = ok(Farm.harvestCycle(farm, { cycleId: "c1", cropsHarvested: 10, seedsReturned: 10, cropPrice: 1000, now: 2 }))
  farm = ok(Farm.plantCycle(farm, { plotId: "p2", crop: "potato", seedsPlanted: 10, seedPrice: 200, now: 3, id: "c2" }))
  farm = ok(Farm.harvestCycle(farm, { cycleId: "c2", cropsHarvested: 0, seedsReturned: 5, cropPrice: 0, now: 4 }))
  farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 10, seedPrice: 100, now: 5, id: "c3" }))
  const t = plain(Farm.totals(farm, 0))
  assert.deepEqual(t.overall, { cycles: 2, profit: 10000 - 1000 })
  assert.deepEqual(t.byPlot.p1, { cycles: 1, profit: 10000 })
  assert.deepEqual(t.byPlot.p2, { cycles: 1, profit: -1000 })
  assert.deepEqual(t.byCrop.turnip, { cycles: 1, profit: 10000 })
  assert.deepEqual(t.byCrop.potato, { cycles: 1, profit: -1000 })
})

test("totals: empty farm", () => {
  assert.deepEqual(plain(Farm.totals(empty(), 0.065)), { overall: { cycles: 0, profit: 0 }, byPlot: {}, byCrop: {} })
})

test("setTaxRate: accepts 0..1, rejects the rest", () => {
  assert.equal(plain(ok(Farm.setTaxRate(empty(), 0.04))).settings.taxRate, 0.04)
  for (const bad of [-0.1, 1.5, NaN, "x", null]) assert.equal(Farm.setTaxRate(empty(), bad).ok, false, String(bad))
})

test("sanitizeFarm: keeps valid data and fills settings default", () => {
  const farm = ok({ ok: true, farm: Farm.sanitizeFarm({ plots: [], cycles: [] }) })
  assert.deepEqual(farm, empty())
})

test("sanitizeFarm: drops malformed plots, cycles, unknown plots/crops and second open cycles", () => {
  const goodCycle = (id, extra) => Object.assign({
    id, plotId: "p1", crop: "turnip", plantedAt: 1, seedsPlanted: 9, seedPrice: 100,
    harvestedAt: null, cropsHarvested: 0, seedsReturned: 0, cropPrice: 0
  }, extra)
  const r = plain(Farm.sanitizeFarm({
    plots: [{ id: "p1", name: "A" }, { id: "p1", name: "dup id" }, { id: "p2" }, null, "x", { id: "p3", name: "  " }],
    cycles: [
      goodCycle("c1"),
      goodCycle("c2"), // second open cycle on p1
      goodCycle("c3", { plotId: "zzz" }),
      goodCycle("c4", { crop: "nope" }),
      goodCycle("c5", { seedsPlanted: -1 }),
      goodCycle("c6", { harvestedAt: 9, cropsHarvested: 4, seedsReturned: 1, cropPrice: 10 }),
      goodCycle("c1", { harvestedAt: 9 }), // duplicate id
      goodCycle("c7", { harvestedAt: 9, cropPrice: "x" }),
      42
    ],
    settings: { taxRate: 0.04, junk: 1 }
  }))
  assert.deepEqual(r.plots, [{ id: "p1", name: "A" }])
  assert.deepEqual(r.cycles.map((c) => c.id), ["c1", "c6"])
  assert.deepEqual(r.settings, { ...DEFAULT_SETTINGS, taxRate: 0.04 })
})

test("sanitizeFarm: invalid or missing tax rate falls back to the default", () => {
  for (const settings of [undefined, {}, { taxRate: "x" }, { taxRate: 2 }, { taxRate: -1 }]) {
    assert.equal(Farm.sanitizeFarm({ plots: [], cycles: [], settings }).settings.taxRate, 0.065)
  }
  assert.equal(Farm.sanitizeFarm(null).settings.taxRate, 0.065)
})

test("parseInteger: plain and grouped digits, rejects the rest", () => {
  assert.equal(Farm.parseInteger("1234"), 1234)
  assert.equal(Farm.parseInteger(" 1,234 "), 1234)
  assert.equal(Farm.parseInteger("1 234"), 1234)
  assert.equal(Farm.parseInteger("0"), 0)
  for (const bad of ["", "abc", "-5", "1.5x", null, undefined]) assert.equal(Farm.parseInteger(bad), null, String(bad))
})

test("parsePercent and formatPercent", () => {
  assert.equal(Farm.parsePercent("6.5"), 0.065)
  assert.equal(Farm.parsePercent("6,5"), 0.065)
  assert.equal(Farm.parsePercent("0"), 0)
  for (const bad of ["", "x", "-1", "101"]) assert.equal(Farm.parsePercent(bad), null, bad)
  assert.equal(Farm.formatPercent(0.065), "6.5")
  assert.equal(Farm.formatPercent(0.04), "4")
})

test("formatSilver: thousands separators and sign", () => {
  assert.equal(Farm.formatSilver(0), "0")
  assert.equal(Farm.formatSilver(999), "999")
  assert.equal(Farm.formatSilver(1234567), "1,234,567")
  assert.equal(Farm.formatSilver(-46850), "-46,850")
  assert.equal(Farm.formatSilver(null), "-")
})

test("openCycle: finds the open cycle of a plot, null otherwise", () => {
  const farm = withOpenCycle()
  assert.equal(Farm.openCycle(farm, "p1").id, "c1")
  assert.equal(Farm.openCycle(farm, "zzz"), null)
  const closed = ok(Farm.harvestCycle(farm, { cycleId: "c1", cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: 2000 }))
  assert.equal(Farm.openCycle(closed, "p1"), null)
})

test("closedCycles: newest harvest first, optional limit", () => {
  let farm = withPlot()
  const times = [[10, 20], [30, 40], [50, 60]]
  times.forEach(([plant, harvest], n) => {
    farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 1, seedPrice: 0, now: plant, id: "c" + n }))
    farm = ok(Farm.harvestCycle(farm, { cycleId: "c" + n, cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: harvest }))
  })
  farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 1, seedPrice: 0, now: 70, id: "open" }))
  assert.deepEqual(plain(Farm.closedCycles(farm)).map((c) => c.id), ["c2", "c1", "c0"])
  assert.deepEqual(plain(Farm.closedCycles(farm, 2)).map((c) => c.id), ["c2", "c1"])
})

function withHistory() {
  let farm = withPlot("A", "p1")
  farm = ok(Farm.addPlot(farm, "B", "p2"))
  farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 10, seedPrice: 100, now: 1, id: "c1" }))
  farm = ok(Farm.harvestCycle(farm, { cycleId: "c1", cropsHarvested: 10, seedsReturned: 10, cropPrice: 1000, now: 2 }))
  farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 10, seedPrice: 100, now: 3, id: "c2" }))
  farm = ok(Farm.plantCycle(farm, { plotId: "p2", crop: "potato", seedsPlanted: 5, seedPrice: 100, now: 4, id: "c3" }))
  return farm
}

test("removeCycle: drops an open cycle (cancel planting) and frees the plot", () => {
  const farm = ok(Farm.removeCycle(withHistory(), "c2"))
  assert.deepEqual(farm.cycles.map((c) => c.id), ["c1", "c3"])
  assert.equal(Farm.openCycle(farm, "p1"), null)
  assert.deepEqual(farm.plots.map((p) => p.id), ["p1", "p2"])
})

test("removeCycle: drops a closed cycle from totals", () => {
  const farm = ok(Farm.removeCycle(withHistory(), "c1"))
  assert.deepEqual(plain(Farm.totals(farm, 0)).overall, { cycles: 0, profit: 0 })
})

test("removeCycle: unknown id fails in Spanish and input is not mutated", () => {
  const before = withHistory()
  const r = Farm.removeCycle(before, "zzz")
  assert.equal(r.ok, false)
  assert.match(r.error, /ciclo/i)
  Farm.removeCycle(before, "c1")
  assert.equal(before.cycles.length, 3)
})

test("removePlot: removes the plot and all of its cycles, keeps the rest", () => {
  const farm = ok(Farm.removePlot(withHistory(), "p1"))
  assert.deepEqual(farm.plots, [{ id: "p2", name: "B" }])
  assert.deepEqual(farm.cycles.map((c) => c.id), ["c3"])
  assert.equal(farm.settings.taxRate, 0.065)
})

test("removePlot: unknown id fails in Spanish and input is not mutated", () => {
  const before = withHistory()
  const r = Farm.removePlot(before, "zzz")
  assert.equal(r.ok, false)
  assert.match(r.error, /parcela/i)
  Farm.removePlot(before, "p1")
  assert.equal(before.plots.length, 2)
  assert.equal(before.cycles.length, 3)
})

test("sanitizeFarm: planner settings keep valid values and default the invalid ones", () => {
  const good = Farm.sanitizeFarm({ plots: [], cycles: [], settings: { taxRate: 0.04, premium: false, focus: false, seedsPerPlot: 7 } })
  assert.deepEqual(plain(good.settings), { taxRate: 0.04, premium: false, focus: false, seedsPerPlot: 7 })
  for (const bad of ["x", 0, -3, 2.5, 1001, null, NaN]) {
    const s = Farm.sanitizeFarm({ plots: [], cycles: [], settings: { seedsPerPlot: bad, premium: "yes", focus: 1 } }).settings
    assert.equal(s.seedsPerPlot, 9, String(bad))
    assert.equal(s.premium, true)
    assert.equal(s.focus, true)
  }
})

test("setPlannerSettings: merges valid fields and keeps the rest", () => {
  const farm = ok(Farm.setPlannerSettings(empty(), { premium: false, seedsPerPlot: 12 }))
  assert.deepEqual(farm.settings, { taxRate: 0.065, premium: false, focus: true, seedsPerPlot: 12 })
})

test("setPlannerSettings: rejects bad values in Spanish", () => {
  for (const patch of [{ seedsPerPlot: 0 }, { seedsPerPlot: 1.5 }, { seedsPerPlot: 5000 }, { seedsPerPlot: "x" }, { premium: "si" }, { focus: 1 }]) {
    const r = Farm.setPlannerSettings(empty(), patch)
    assert.equal(r.ok, false, JSON.stringify(patch))
    assert.equal(typeof r.error, "string")
  }
})

test("setTaxRate keeps the planner settings", () => {
  const start = ok(Farm.setPlannerSettings(empty(), { focus: false }))
  assert.deepEqual(ok(Farm.setTaxRate(start, 0.04)).settings, { taxRate: 0.04, premium: true, focus: false, seedsPerPlot: 9 })
})

test("parseSilver: plain integers and thousands separators", () => {
  assert.equal(Farm.parseSilver("0"), 0)
  assert.equal(Farm.parseSilver("1234"), 1234)
  assert.equal(Farm.parseSilver(" 12000 "), 12000)
  assert.equal(Farm.parseSilver("1.500.000"), 1500000)
  assert.equal(Farm.parseSilver("1,500,000"), 1500000)
  assert.equal(Farm.parseSilver("1.500"), 1500)
  assert.equal(Farm.parseSilver("1,234"), 1234)
  assert.equal(Farm.parseSilver("1 234 567"), 1234567)
})

test("parseSilver: k and m suffixes, case-insensitive, decimal point or comma", () => {
  assert.equal(Farm.parseSilver("450k"), 450000)
  assert.equal(Farm.parseSilver("450K"), 450000)
  assert.equal(Farm.parseSilver("1.2m"), 1200000)
  assert.equal(Farm.parseSilver("12,5k"), 12500)
  assert.equal(Farm.parseSilver("2M"), 2000000)
  assert.equal(Farm.parseSilver("0.5m"), 500000)
  assert.equal(Farm.parseSilver("1.1m"), 1100000)
  assert.equal(Farm.parseSilver("1.2345m"), 1234500)
  assert.equal(Farm.parseSilver("1.500k"), 1500000)
  assert.equal(Farm.parseSilver("1,500,000k"), 1500000000)
})

test("parseSilver: a single separator that is not 3 digits needs a suffix", () => {
  for (const bad of ["1.5", "1,5", "12.50", "0,25"]) assert.equal(Farm.parseSilver(bad), null, bad)
})

test("parseSilver: rejects invalid or ambiguous input", () => {
  const bad = ["", "  ", "abc", "-5", "-1k", "+5", "1.2.3k", "1,5.2k", "1.500,000", "12kk", "1k2", "k", "m", ".5k", "5.k", "1e5", "1.2345k", "1 23", "1.5 m", "10 k", null, undefined, 5, "9999999999999999999"]
  for (const text of bad) assert.equal(Farm.parseSilver(text), null, String(text))
})

test("parseSilver: round trip with formatSilver", () => {
  for (const n of [0, 7, 999, 1000, 12345, 1500000, 987654321]) assert.equal(Farm.parseSilver(Farm.formatSilver(n)), n, String(n))
})

test("formatShort: shorthand when exact, grouped digits otherwise", () => {
  assert.equal(Farm.formatShort(12000), "12k")
  assert.equal(Farm.formatShort(12500), "12.5k")
  assert.equal(Farm.formatShort(1200000), "1.2m")
  assert.equal(Farm.formatShort(2000000), "2m")
  assert.equal(Farm.formatShort(950), "950")
  assert.equal(Farm.formatShort(1234), "1,234")
  assert.equal(Farm.formatShort(1234567), "1,234,567")
  assert.equal(Farm.formatShort("x"), "-")
  for (const n of [0, 950, 1234, 12000, 12500, 1200000, 2000000, 1234567]) assert.equal(Farm.parseSilver(Farm.formatShort(n)), n, String(n))
})

const HOUR = 3600 * 1000

test("plotState: empty without an open cycle, also for unknown plots", () => {
  const farm = withPlot()
  assert.equal(Farm.plotState(farm, "p1", 5000), "empty")
  assert.equal(Farm.plotState(farm, "zzz", 5000), "empty")
  const closed = ok(Farm.harvestCycle(withOpenCycle(), { cycleId: "c1", cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: 2000 }))
  assert.equal(Farm.plotState(closed, "p1", 5000), "empty")
})

test("plotState: planted while growing, ready once the 22 h growth time has passed", () => {
  const farm = withOpenCycle()
  assert.equal(Farm.GROWTH_MS, 22 * HOUR)
  assert.equal(Farm.plotState(farm, "p1", 1000), "planted")
  assert.equal(Farm.plotState(farm, "p1", 1000 + 22 * HOUR - 1), "planted")
  assert.equal(Farm.plotState(farm, "p1", 1000 + 22 * HOUR), "ready")
  assert.equal(Farm.plotState(farm, "p1", 1000 + 40 * HOUR), "ready")
})

test("plotState: a clock before plantedAt still reads as planted; no clock never reads as ready", () => {
  const farm = withOpenCycle()
  assert.equal(Farm.plotState(farm, "p1", 10), "planted")
  assert.equal(Farm.plotState(farm, "p1"), "planted")
  assert.equal(Farm.plotState(farm, "p1", NaN), "planted")
})

test("plotStateLabel: Spanish labels for every state", () => {
  assert.equal(Farm.plotStateLabel("empty"), "Vacía")
  assert.equal(Farm.plotStateLabel("planted"), "Creciendo")
  assert.equal(Farm.plotStateLabel("ready"), "Lista para cosechar")
  assert.equal(Farm.plotStateLabel("???"), "Vacía")
})

test("closedCycles(3): the three most recent harvests feed the short history", () => {
  let farm = withPlot()
  for (let n = 0; n < 5; n++) {
    farm = ok(Farm.plantCycle(farm, { plotId: "p1", crop: "turnip", seedsPlanted: 1, seedPrice: 0, now: n * 10, id: "c" + n }))
    farm = ok(Farm.harvestCycle(farm, { cycleId: "c" + n, cropsHarvested: 1, seedsReturned: 0, cropPrice: 1, now: n * 10 + 5 }))
  }
  assert.deepEqual(plain(Farm.closedCycles(farm, 3)).map((c) => c.id), ["c4", "c3", "c2"])
  assert.equal(Farm.closedCycles(farm).length, 5)
})
