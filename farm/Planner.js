.pragma library

// Rotation planner: which crop is expected to pay most per plot cycle.
// Pure and independent: the crop catalog (Farm.CROPS) is injected by the
// caller because modules do not import each other.
//
// Yield source per crop: the user's own closed cycles ("historial") when
// there is at least one, otherwise the game's estimate ("estimado").
//
// Constants come from the game data dumps (ao-bin-dumps, fetched 2026-10-11):
//   https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/loot.xml
//   https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/items.xml
// - Crops per harvested seed: loot.xml T<n>_<CROP>_LOOT amount="3-6" -> avg 4.5.
// - Seed return per harvested plant: items.xml <seed chance>, and with focus
//   watering chance + activefarmbonus.
// - Premium doubling the crop yield is NOT in the dumps; it comes from
//   https://wiki.albiononline.com/wiki/Crops (medium-high confidence).
// - Assumed: premium does not change the seed return. Seeds per plot (9) is
//   a user setting because its only source is a guide snippet.

var CROPS_PER_SEED = 4.5
var PREMIUM_CROP_MULTIPLIER = 2

var DEFAULT_TAX_RATE = 0.065
var DEFAULT_SEEDS_PER_PLOT = 9

// Seeds returned per seed planted, without and with focus watering.
var SEED_RETURN = {
  carrot: { noFocus: 0, focus: 2 },
  bean: { noFocus: 0.3333, focus: 1.6667 },
  wheat: { noFocus: 0.6, focus: 1.4 },
  turnip: { noFocus: 0.7333, focus: 1.2667 },
  cabbage: { noFocus: 0.8, focus: 1.2 },
  potato: { noFocus: 0.8667, focus: 1.1333 },
  corn: { noFocus: 0.9111, focus: 1.0889 },
  pumpkin: { noFocus: 0.9333, focus: 1.0667 }
}

function normalizeSettings(raw) {
  var s = raw && typeof raw === "object" ? raw : {}
  return {
    taxRate: typeof s.taxRate === "number" && s.taxRate >= 0 && s.taxRate <= 1 ? s.taxRate : DEFAULT_TAX_RATE,
    premium: typeof s.premium === "boolean" ? s.premium : true,
    focus: typeof s.focus === "boolean" ? s.focus : true,
    seedsPerPlot: typeof s.seedsPerPlot === "number" && s.seedsPerPlot >= 1 ? s.seedsPerPlot : DEFAULT_SEEDS_PER_PLOT
  }
}

// Game estimate for one crop, or null for an unknown crop.
function estimatedYield(cropKey, settings) {
  var returns = SEED_RETURN[cropKey]
  if (!returns) return null
  var s = normalizeSettings(settings)
  return {
    cropsPerSeed: CROPS_PER_SEED * (s.premium ? PREMIUM_CROP_MULTIPLIER : 1),
    seedReturnPerSeed: s.focus ? returns.focus : returns.noFocus
  }
}

// Yield measured on closed cycles of one crop, or null without history.
// Cycles with seedsPlanted 0 are ignored.
function historyYield(cycles, cropKey) {
  var planted = 0
  var crops = 0
  var returned = 0
  var count = 0
  var list = Array.isArray(cycles) ? cycles : []
  for (var i = 0; i < list.length; i++) {
    var c = list[i]
    if (!c || c.crop !== cropKey || c.harvestedAt === null || c.harvestedAt === undefined) continue
    if (!(c.seedsPlanted > 0)) continue
    planted += c.seedsPlanted
    crops += c.cropsHarvested
    returned += c.seedsReturned
    count += 1
  }
  if (count === 0) return null
  return { cropsPerSeed: crops / planted, seedReturnPerSeed: returned / planted, cycles: count }
}

// input: { seedsPerPlot, cropsPerSeed, seedReturnPerSeed, cropPrice|null,
//          seedPrice|null, taxRate }
// Returns { profit, partial }:
// - no crop price: profit null.
// - no seed price: the seed term is skipped. If the net seeds are 0 that is
//   exact; otherwise the profit counts crop sales only and partial is true.
function expectedProfit(input) {
  if (input.cropPrice === null || input.cropPrice === undefined) return { profit: null, partial: false }
  var sales = input.seedsPerPlot * input.cropsPerSeed * input.cropPrice * (1 - input.taxRate)
  var netSeeds = input.seedsPerPlot * input.seedReturnPerSeed - input.seedsPerPlot
  if (input.seedPrice === null || input.seedPrice === undefined) {
    return { profit: Math.round(sales), partial: Math.abs(netSeeds) > 1e-9 }
  }
  return { profit: Math.round(sales + netSeeds * input.seedPrice), partial: false }
}

function priceOf(prices, id) {
  var v = prices && typeof prices === "object" ? prices[id] : null
  return typeof v === "number" && v > 0 ? v : null
}

// Ranks every crop of the catalog by expected profit per plot cycle.
// Order: complete rows by profit desc, then partial rows by profit desc, then
// rows without a crop price ("sin precio").
// Row: { crop, name, tier, source, cropsPerSeed, seedReturnPerSeed,
//        cropPrice, seedPrice, profit, partial }
function rankCrops(farm, prices, catalog) {
  var f = farm && typeof farm === "object" ? farm : {}
  var settings = normalizeSettings(f.settings)
  var rows = []
  var crops = Array.isArray(catalog) ? catalog : []
  for (var i = 0; i < crops.length; i++) {
    var crop = crops[i]
    var history = historyYield(f.cycles, crop.key)
    var yieldInfo = history || estimatedYield(crop.key, settings)
    if (!yieldInfo) continue
    var cropPrice = priceOf(prices, crop.cropId)
    var seedPrice = priceOf(prices, crop.seedId)
    var result = expectedProfit({
      seedsPerPlot: settings.seedsPerPlot, cropsPerSeed: yieldInfo.cropsPerSeed,
      seedReturnPerSeed: yieldInfo.seedReturnPerSeed, cropPrice: cropPrice,
      seedPrice: seedPrice, taxRate: settings.taxRate
    })
    rows.push({
      crop: crop.key, name: crop.name, tier: crop.tier, source: history ? "historial" : "estimado",
      cropsPerSeed: yieldInfo.cropsPerSeed, seedReturnPerSeed: yieldInfo.seedReturnPerSeed,
      cropPrice: cropPrice, seedPrice: seedPrice, profit: result.profit, partial: result.partial
    })
  }
  rows.sort(function(a, b) {
    var ga = a.profit === null ? 2 : (a.partial ? 1 : 0)
    var gb = b.profit === null ? 2 : (b.partial ? 1 : 0)
    if (ga !== gb) return ga - gb
    if (a.profit === null) return a.tier - b.tier
    return b.profit - a.profit
  })
  return rows
}
