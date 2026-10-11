import { test } from "node:test"
import assert from "node:assert/strict"
import { loadFarm, loadPlanner, plain } from "./helpers/load-model.mjs"

const Farm = loadFarm()
const Planner = loadPlanner()
const CROPS = Farm.CROPS

const settings = (extra) => Object.assign({ taxRate: 0.1, premium: true, focus: true, seedsPerPlot: 9 }, extra)
const farmOf = (cycles, s) => ({ plots: [{ id: "p1", name: "A" }], cycles: cycles || [], settings: settings(s) })
const closed = (id, crop, extra) => Object.assign({
  id, plotId: "p1", crop, plantedAt: 1, seedsPlanted: 10, seedPrice: 100,
  harvestedAt: 2, cropsHarvested: 50, seedsReturned: 12, cropPrice: 200
}, extra)
const rank = (farm, prices) => plain(Planner.rankCrops(farm, prices, CROPS))
const row = (rows, key) => rows.find((r) => r.crop === key)

test("constants: crop yield and seed return per tier", () => {
  assert.equal(Planner.CROPS_PER_SEED, 4.5)
  assert.equal(Planner.PREMIUM_CROP_MULTIPLIER, 2)
  assert.equal(Planner.SEED_RETURN.carrot.focus, 2)
  assert.equal(Planner.SEED_RETURN.pumpkin.noFocus, 0.9333)
  assert.equal(Object.keys(Planner.SEED_RETURN).length, 8)
})

test("estimatedYield: premium doubles crops, focus picks the seed return column", () => {
  const a = plain(Planner.estimatedYield("potato", { premium: true, focus: true }))
  assert.deepEqual(a, { cropsPerSeed: 9, seedReturnPerSeed: 1.1333 })
  const b = plain(Planner.estimatedYield("potato", { premium: false, focus: false }))
  assert.deepEqual(b, { cropsPerSeed: 4.5, seedReturnPerSeed: 0.8667 })
})

test("estimatedYield: unknown crop is null", () => {
  assert.equal(Planner.estimatedYield("nope", {}), null)
})

test("historyYield: aggregates closed cycles, ignores open and seedsPlanted 0", () => {
  const cycles = [
    closed("c1", "turnip", { seedsPlanted: 10, cropsHarvested: 90, seedsReturned: 10 }),
    closed("c2", "turnip", { seedsPlanted: 10, cropsHarvested: 70, seedsReturned: 14 }),
    closed("c3", "turnip", { harvestedAt: null }),
    closed("c4", "turnip", { seedsPlanted: 0, cropsHarvested: 999, seedsReturned: 999 }),
    closed("c5", "potato")
  ]
  assert.deepEqual(plain(Planner.historyYield(cycles, "turnip")), { cropsPerSeed: 8, seedReturnPerSeed: 1.2, cycles: 2 })
  assert.equal(Planner.historyYield(cycles, "corn"), null)
  assert.equal(Planner.historyYield([closed("z", "corn", { seedsPlanted: 0 })], "corn"), null)
})

test("expectedProfit: crop sales after tax plus net seeds at seed price", () => {
  // 9 * 8 * 200 * 0.9 + (9 * 1.2 - 9) * 100 = 12960 + 180
  const p = Planner.expectedProfit({ seedsPerPlot: 9, cropsPerSeed: 8, seedReturnPerSeed: 1.2, cropPrice: 200, seedPrice: 100, taxRate: 0.1 })
  assert.equal(p.profit, 13140)
  assert.equal(p.partial, false)
})

test("expectedProfit: missing crop price gives null profit", () => {
  const p = plain(Planner.expectedProfit({ seedsPerPlot: 9, cropsPerSeed: 8, seedReturnPerSeed: 1.2, cropPrice: null, seedPrice: 100, taxRate: 0.1 }))
  assert.deepEqual(p, { profit: null, partial: false })
})

test("expectedProfit: missing seed price with zero net seeds is complete", () => {
  const p = Planner.expectedProfit({ seedsPerPlot: 9, cropsPerSeed: 8, seedReturnPerSeed: 1, cropPrice: 200, seedPrice: null, taxRate: 0.1 })
  assert.equal(p.profit, 12960)
  assert.equal(p.partial, false)
})

test("expectedProfit: missing seed price with nonzero net seeds is partial (crop sales only)", () => {
  const p = Planner.expectedProfit({ seedsPerPlot: 9, cropsPerSeed: 8, seedReturnPerSeed: 1.2, cropPrice: 200, seedPrice: null, taxRate: 0.1 })
  assert.equal(p.profit, 12960)
  assert.equal(p.partial, true)
})

test("rankCrops: one row per crop with the documented shape", () => {
  const rows = rank(farmOf(), {})
  assert.equal(rows.length, 8)
  assert.deepEqual(Object.keys(rows[0]).sort(), ["crop", "cropPrice", "cropsPerSeed", "name", "partial", "profit", "seedPrice", "seedReturnPerSeed", "source", "tier"])
})

test("rankCrops: estimate from constants and settings when there is no history", () => {
  const prices = { T4_TURNIP: 1000, T4_FARM_TURNIP_SEED: 500 }
  const r = row(rank(farmOf(), prices), "turnip")
  assert.equal(r.source, "estimado")
  assert.equal(r.cropsPerSeed, 9)
  assert.equal(r.seedReturnPerSeed, 1.2667)
  // 9*9*1000*0.9 + (9*1.2667 - 9)*500 = 72900 + 1200 (rounded)
  assert.equal(r.profit, Math.round(72900 + (9 * 1.2667 - 9) * 500))
  assert.equal(r.cropPrice, 1000)
  assert.equal(r.seedPrice, 500)
})

test("rankCrops: settings change the estimate", () => {
  const prices = { T4_TURNIP: 1000, T4_FARM_TURNIP_SEED: 500 }
  const r = row(rank(farmOf([], { premium: false, focus: false, seedsPerPlot: 10 }), prices), "turnip")
  assert.equal(r.cropsPerSeed, 4.5)
  assert.equal(r.seedReturnPerSeed, 0.7333)
  assert.equal(r.profit, Math.round(10 * 4.5 * 1000 * 0.9 + (10 * 0.7333 - 10) * 500))
})

test("rankCrops: history wins over the estimate and is labeled historial", () => {
  const farm = farmOf([closed("c1", "turnip", { seedsPlanted: 10, cropsHarvested: 80, seedsReturned: 10 })])
  const r = row(rank(farm, { T4_TURNIP: 1000, T4_FARM_TURNIP_SEED: 500 }), "turnip")
  assert.equal(r.source, "historial")
  assert.equal(r.cropsPerSeed, 8)
  assert.equal(r.seedReturnPerSeed, 1)
  assert.equal(r.profit, Math.round(9 * 8 * 1000 * 0.9))
})

test("rankCrops: sorted by profit desc; partial after complete; no price last", () => {
  const prices = {
    T1_CARROT: 100, T1_FARM_CARROT_SEED: 10,
    T4_TURNIP: 2000, T4_FARM_TURNIP_SEED: 50,
    T6_POTATO: 99999, // partial: seed price missing, net seeds nonzero
    T8_PUMPKIN: null, T8_FARM_PUMPKIN_SEED: 10
  }
  const rows = rank(farmOf(), prices)
  const order = rows.map((r) => r.crop)
  assert.deepEqual(order.slice(0, 3), ["turnip", "carrot", "potato"])
  assert.equal(row(rows, "potato").partial, true)
  assert.equal(row(rows, "pumpkin").profit, null)
  assert.ok(order.indexOf("pumpkin") >= 3)
  for (const k of ["bean", "wheat", "cabbage", "corn", "pumpkin"]) assert.equal(row(rows, k).profit, null)
  assert.equal(rows[0].profit >= rows[1].profit, true)
})

test("rankCrops: tolerates a missing prices map and missing settings", () => {
  const rows = plain(Planner.rankCrops({ plots: [], cycles: [] }, undefined, CROPS))
  assert.equal(rows.length, 8)
  assert.ok(rows.every((r) => r.profit === null))
})

test("rankCrops: does not mutate its inputs", () => {
  const farm = farmOf([closed("c1", "turnip")])
  const before = JSON.stringify(farm)
  Planner.rankCrops(farm, { T4_TURNIP: 1 }, CROPS)
  assert.equal(JSON.stringify(farm), before)
})
