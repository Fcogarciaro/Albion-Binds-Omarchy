.pragma library

// Tracker data (farm and black zone) lives in
// ~/.local/share/albion-companion/data.json, separate from the binds, which
// stay in the shell settings.

var DATA_VERSION = 1

// Mirror Farm.js defaults (modules do not import each other).
var DEFAULT_TAX_RATE = 0.065
var DEFAULT_SEEDS_PER_PLOT = 9
var MAX_SEEDS_PER_PLOT = 1000

function defaultData() {
  return {
    version: DATA_VERSION,
    farm: { plots: [], cycles: [], settings: settingsOr(null) },
    blackzone: { sets: [], events: [] }
  }
}

function listOr(value) {
  return Array.isArray(value) ? value : []
}

// Farm settings with every field validated; invalid ones take the default.
function settingsOr(settings) {
  var s = settings && typeof settings === "object" ? settings : {}
  var seeds = s.seedsPerPlot
  return {
    taxRate: typeof s.taxRate === "number" && isFinite(s.taxRate) && s.taxRate >= 0 && s.taxRate <= 1 ? s.taxRate : DEFAULT_TAX_RATE,
    premium: typeof s.premium === "boolean" ? s.premium : true,
    focus: typeof s.focus === "boolean" ? s.focus : true,
    seedsPerPlot: typeof seeds === "number" && Math.floor(seeds) === seeds && seeds >= 1 && seeds <= MAX_SEEDS_PER_PLOT ? seeds : DEFAULT_SEEDS_PER_PLOT
  }
}

// Parses the data file into { ok: true, data } or { ok: false, error }.
// Missing or wrongly typed sections fall back to their defaults.
// sanitizeFarm (optional, e.g. Farm.sanitizeFarm) cleans farm plots/cycles;
// it is injected because modules do not import each other.
function parseData(text, sanitizeFarm) {
  var raw
  try {
    raw = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "El archivo de datos no es JSON válido." }
  }
  if (raw === null || typeof raw !== "object" || Array.isArray(raw))
    return { ok: false, error: "El archivo de datos no tiene el formato esperado." }
  if (raw.version !== undefined && !(Number(raw.version) <= DATA_VERSION))
    return { ok: false, error: "El archivo de datos es de una versión más nueva de Albion Companion." }

  var farm = raw.farm && typeof raw.farm === "object" ? raw.farm : {}
  var blackzone = raw.blackzone && typeof raw.blackzone === "object" ? raw.blackzone : {}
  var farmData = {
    plots: listOr(farm.plots),
    cycles: listOr(farm.cycles),
    settings: settingsOr(farm.settings)
  }
  if (typeof sanitizeFarm === "function") farmData = sanitizeFarm(farmData)
  return {
    ok: true,
    data: {
      version: DATA_VERSION,
      farm: farmData,
      blackzone: { sets: listOr(blackzone.sets), events: listOr(blackzone.events) }
    }
  }
}

function serializeData(data) {
  return JSON.stringify(data, null, 2) + "\n"
}

// Decides what to do with the text read after the file changed on disk.
// lastWritten is the text this plugin last saved: seeing it again is our own
// write echoing back. Returns { action: "same" } (nothing to apply),
// { action: "apply", data } or { action: "error", error } (keep the current
// document).
function reloadOutcome(text, lastWritten, current, sanitizeFarm) {
  if (text === lastWritten) return { action: "same" }
  var result = parseData(text, sanitizeFarm)
  if (!result.ok) return { action: "error", error: result.error }
  if (serializeData(result.data) === serializeData(current)) return { action: "same" }
  return { action: "apply", data: result.data }
}
