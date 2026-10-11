.pragma library

// Farm profit log: crop catalog, plot/cycle operations and profit math.
// Pure and immutable: every operation returns new data. Ids and timestamps
// are injected by the caller so results stay deterministic.
//
// Farm shape: { plots: [{ id, name }], cycles: [Cycle], settings: { taxRate } }
// Cycle: { id, plotId, crop, plantedAt, seedsPlanted, seedPrice,
//          harvestedAt|null, cropsHarvested, seedsReturned, cropPrice }

// 4% premium sales tax + 2.5% sell-order setup fee.
var DEFAULT_TAX_RATE = 0.065

var CROPS = [
  { tier: 1, key: "carrot", name: "Zanahoria", cropId: "T1_CARROT", seedId: "T1_FARM_CARROT_SEED" },
  { tier: 2, key: "bean", name: "Frijol", cropId: "T2_BEAN", seedId: "T2_FARM_BEAN_SEED" },
  { tier: 3, key: "wheat", name: "Trigo", cropId: "T3_WHEAT", seedId: "T3_FARM_WHEAT_SEED" },
  { tier: 4, key: "turnip", name: "Nabo", cropId: "T4_TURNIP", seedId: "T4_FARM_TURNIP_SEED" },
  { tier: 5, key: "cabbage", name: "Repollo", cropId: "T5_CABBAGE", seedId: "T5_FARM_CABBAGE_SEED" },
  { tier: 6, key: "potato", name: "Papa", cropId: "T6_POTATO", seedId: "T6_FARM_POTATO_SEED" },
  { tier: 7, key: "corn", name: "Maíz", cropId: "T7_CORN", seedId: "T7_FARM_CORN_SEED" },
  { tier: 8, key: "pumpkin", name: "Calabaza", cropId: "T8_PUMPKIN", seedId: "T8_FARM_PUMPKIN_SEED" }
]

var MAX_PLOT_NAME = 40

function cropByKey(key) {
  for (var i = 0; i < CROPS.length; i++) {
    if (CROPS[i].key === key) return CROPS[i]
  }
  return null
}

function isNonNegativeInt(v) {
  return typeof v === "number" && isFinite(v) && v >= 0 && Math.floor(v) === v
}

function validTaxRate(v) {
  return typeof v === "number" && isFinite(v) && v >= 0 && v <= 1
}

function fail(error) {
  return { ok: false, error: error }
}

function normalizeFarm(farm) {
  var f = farm && typeof farm === "object" ? farm : {}
  return {
    plots: Array.isArray(f.plots) ? f.plots : [],
    cycles: Array.isArray(f.cycles) ? f.cycles : [],
    settings: { taxRate: f.settings && validTaxRate(f.settings.taxRate) ? f.settings.taxRate : DEFAULT_TAX_RATE }
  }
}

function withCycles(farm, cycles) {
  return { plots: farm.plots, cycles: cycles, settings: farm.settings }
}

function findCycle(farm, id) {
  for (var i = 0; i < farm.cycles.length; i++) {
    if (farm.cycles[i].id === id) return i
  }
  return -1
}

function hasOpenCycle(cycles, plotId) {
  return cycles.some(function(c) { return c.plotId === plotId && c.harvestedAt === null })
}

// ---------- Sanitizing ----------

function sanitizePlot(raw) {
  if (!raw || typeof raw !== "object") return null
  if (typeof raw.id !== "string" || raw.id === "") return null
  if (typeof raw.name !== "string") return null
  var name = raw.name.trim()
  if (name === "") return null
  return { id: raw.id, name: name.slice(0, MAX_PLOT_NAME) }
}

function sanitizeCycle(raw) {
  if (!raw || typeof raw !== "object") return null
  if (typeof raw.id !== "string" || raw.id === "") return null
  if (typeof raw.plotId !== "string" || raw.plotId === "") return null
  if (!cropByKey(raw.crop)) return null
  if (!isNonNegativeInt(raw.plantedAt)) return null
  if (!isNonNegativeInt(raw.seedsPlanted) || raw.seedsPlanted < 1) return null
  if (!isNonNegativeInt(raw.seedPrice)) return null
  var cycle = {
    id: raw.id, plotId: raw.plotId, crop: raw.crop, plantedAt: raw.plantedAt,
    seedsPlanted: raw.seedsPlanted, seedPrice: raw.seedPrice,
    harvestedAt: null, cropsHarvested: 0, seedsReturned: 0, cropPrice: 0
  }
  if (raw.harvestedAt === null || raw.harvestedAt === undefined) return cycle
  if (!isNonNegativeInt(raw.harvestedAt)) return null
  if (!isNonNegativeInt(raw.cropsHarvested) || !isNonNegativeInt(raw.seedsReturned) || !isNonNegativeInt(raw.cropPrice)) return null
  cycle.harvestedAt = raw.harvestedAt
  cycle.cropsHarvested = raw.cropsHarvested
  cycle.seedsReturned = raw.seedsReturned
  cycle.cropPrice = raw.cropPrice
  return cycle
}

// Drops malformed entries, cycles of unknown plots, duplicate ids and any
// second open cycle on the same plot. Never throws.
function sanitizeFarm(raw) {
  var f = raw && typeof raw === "object" ? raw : {}
  var plots = []
  var plotIds = {}
  var list = Array.isArray(f.plots) ? f.plots : []
  for (var i = 0; i < list.length; i++) {
    var plot = sanitizePlot(list[i])
    if (!plot || plotIds[plot.id]) continue
    plotIds[plot.id] = true
    plots.push(plot)
  }

  var cycles = []
  var cycleIds = {}
  var openPlots = {}
  var cyclesRaw = Array.isArray(f.cycles) ? f.cycles : []
  for (var j = 0; j < cyclesRaw.length; j++) {
    var cycle = sanitizeCycle(cyclesRaw[j])
    if (!cycle || cycleIds[cycle.id] || !plotIds[cycle.plotId]) continue
    if (cycle.harvestedAt === null) {
      if (openPlots[cycle.plotId]) continue
      openPlots[cycle.plotId] = true
    }
    cycleIds[cycle.id] = true
    cycles.push(cycle)
  }

  var taxRate = f.settings && validTaxRate(f.settings.taxRate) ? f.settings.taxRate : DEFAULT_TAX_RATE
  return { plots: plots, cycles: cycles, settings: { taxRate: taxRate } }
}

// ---------- Operations ----------

function addPlot(farm, name, id) {
  var f = normalizeFarm(farm)
  var clean = String(name === undefined || name === null ? "" : name).trim()
  if (clean === "") return fail("Escribe un nombre para la parcela.")
  if (clean.length > MAX_PLOT_NAME) return fail("El nombre de la parcela es muy largo (máx. " + MAX_PLOT_NAME + ").")
  var lower = clean.toLowerCase()
  if (f.plots.some(function(p) { return p.name.toLowerCase() === lower }))
    return fail("Ya existe una parcela con ese nombre.")
  if (typeof id !== "string" || id === "" || f.plots.some(function(p) { return p.id === id }))
    return fail("No pude crear la parcela (id no válido).")
  return { ok: true, farm: { plots: f.plots.concat([{ id: id, name: clean }]), cycles: f.cycles, settings: f.settings } }
}

// input: { plotId, crop, seedsPlanted, seedPrice, now, id }
function plantCycle(farm, input) {
  var f = normalizeFarm(farm)
  var i = input || {}
  if (!f.plots.some(function(p) { return p.id === i.plotId })) return fail("Elige una parcela.")
  if (!cropByKey(i.crop)) return fail("Elige un cultivo.")
  if (!isNonNegativeInt(i.seedsPlanted) || i.seedsPlanted < 1) return fail("Las semillas plantadas deben ser un número entero mayor que 0.")
  if (!isNonNegativeInt(i.seedPrice)) return fail("El precio de la semilla debe ser un número entero (0 o más).")
  if (!isNonNegativeInt(i.now)) return fail("No pude registrar la fecha de siembra.")
  if (typeof i.id !== "string" || i.id === "" || f.cycles.some(function(c) { return c.id === i.id }))
    return fail("No pude crear el ciclo (id no válido).")
  if (hasOpenCycle(f.cycles, i.plotId)) return fail("Esa parcela ya tiene un ciclo abierto. Coséchalo primero.")
  var cycle = {
    id: i.id, plotId: i.plotId, crop: i.crop, plantedAt: i.now,
    seedsPlanted: i.seedsPlanted, seedPrice: i.seedPrice,
    harvestedAt: null, cropsHarvested: 0, seedsReturned: 0, cropPrice: 0
  }
  return { ok: true, farm: withCycles(f, f.cycles.concat([cycle])) }
}

// input: { cycleId, cropsHarvested, seedsReturned, cropPrice, now }
function harvestCycle(farm, input) {
  var f = normalizeFarm(farm)
  var i = input || {}
  var index = findCycle(f, i.cycleId)
  if (index < 0) return fail("No encontré ese ciclo.")
  var current = f.cycles[index]
  if (current.harvestedAt !== null) return fail("Ese ciclo ya está cosechado.")
  if (!isNonNegativeInt(i.cropsHarvested)) return fail("Los cultivos cosechados deben ser un número entero (0 o más).")
  if (!isNonNegativeInt(i.seedsReturned)) return fail("Las semillas devueltas deben ser un número entero (0 o más).")
  if (!isNonNegativeInt(i.cropPrice)) return fail("El precio del cultivo debe ser un número entero (0 o más).")
  if (!isNonNegativeInt(i.now) || i.now < current.plantedAt) return fail("La fecha de cosecha no es válida.")
  var closed = {
    id: current.id, plotId: current.plotId, crop: current.crop, plantedAt: current.plantedAt,
    seedsPlanted: current.seedsPlanted, seedPrice: current.seedPrice,
    harvestedAt: i.now, cropsHarvested: i.cropsHarvested, seedsReturned: i.seedsReturned, cropPrice: i.cropPrice
  }
  var cycles = f.cycles.slice()
  cycles[index] = closed
  return { ok: true, farm: withCycles(f, cycles) }
}

// Drops one cycle (open = cancel planting, closed = remove from history and totals).
function removeCycle(farm, cycleId) {
  var f = normalizeFarm(farm)
  if (findCycle(f, cycleId) < 0) return fail("No encontré ese ciclo.")
  return { ok: true, farm: withCycles(f, f.cycles.filter(function(c) { return c.id !== cycleId })) }
}

// Drops a plot together with all of its cycles.
function removePlot(farm, plotId) {
  var f = normalizeFarm(farm)
  if (!f.plots.some(function(p) { return p.id === plotId })) return fail("No encontré esa parcela.")
  return {
    ok: true,
    farm: {
      plots: f.plots.filter(function(p) { return p.id !== plotId }),
      cycles: f.cycles.filter(function(c) { return c.plotId !== plotId }),
      settings: f.settings
    }
  }
}

function setTaxRate(farm, rate) {
  var f = normalizeFarm(farm)
  if (!validTaxRate(rate)) return fail("El impuesto debe estar entre 0 % y 100 %.")
  return { ok: true, farm: { plots: f.plots, cycles: f.cycles, settings: { taxRate: rate } } }
}

// ---------- Profit ----------

// Silver earned by a closed cycle, rounded; null while the cycle is open.
function cycleProfit(cycle, taxRate) {
  if (!cycle || cycle.harvestedAt === null || cycle.harvestedAt === undefined) return null
  var sales = cycle.cropsHarvested * cycle.cropPrice * (1 - taxRate)
  var seeds = (cycle.seedsReturned - cycle.seedsPlanted) * cycle.seedPrice
  return Math.round(sales + seeds)
}

function addTo(bucket, key, profit) {
  if (!bucket[key]) bucket[key] = { cycles: 0, profit: 0 }
  bucket[key].cycles += 1
  bucket[key].profit += profit
}

// Totals over closed cycles: { overall, byPlot: {plotId}, byCrop: {cropKey} }.
function totals(farm, taxRate) {
  var f = normalizeFarm(farm)
  var result = { overall: { cycles: 0, profit: 0 }, byPlot: {}, byCrop: {} }
  for (var i = 0; i < f.cycles.length; i++) {
    var profit = cycleProfit(f.cycles[i], taxRate)
    if (profit === null) continue
    result.overall.cycles += 1
    result.overall.profit += profit
    addTo(result.byPlot, f.cycles[i].plotId, profit)
    addTo(result.byCrop, f.cycles[i].crop, profit)
  }
  return result
}

// ---------- Input / output helpers ----------

// Whole number typed by the user; spaces, commas and dots are grouping.
function parseInteger(text) {
  if (text === null || text === undefined) return null
  var t = String(text).replace(/[\s,.]/g, "")
  return /^[0-9]+$/.test(t) ? Number(t) : null
}

// "6.5" or "6,5" (percent) -> 0.065.
function parsePercent(text) {
  if (text === null || text === undefined) return null
  var t = String(text).trim().replace(",", ".")
  if (!/^[0-9]+(\.[0-9]+)?$/.test(t)) return null
  var value = Number(t)
  return value <= 100 ? Math.round(value * 100) / 10000 : null
}

function formatPercent(rate) {
  return String(Math.round(rate * 10000) / 100)
}

function formatSilver(value) {
  if (typeof value !== "number" || !isFinite(value)) return "-"
  var sign = value < 0 ? "-" : ""
  var digits = String(Math.abs(Math.round(value)))
  return sign + digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// ---------- Queries ----------

function openCycle(farm, plotId) {
  var f = normalizeFarm(farm)
  for (var i = 0; i < f.cycles.length; i++) {
    if (f.cycles[i].plotId === plotId && f.cycles[i].harvestedAt === null) return f.cycles[i]
  }
  return null
}

// Closed cycles, newest harvest first; limit (optional) caps the result.
function closedCycles(farm, limit) {
  var closed = normalizeFarm(farm).cycles.filter(function(c) { return c.harvestedAt !== null })
  closed.sort(function(a, b) { return b.harvestedAt - a.harvestedAt })
  return limit > 0 ? closed.slice(0, limit) : closed
}
