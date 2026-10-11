.pragma library

// Tracker data (farm and black zone) lives in
// ~/.local/share/albion-companion/data.json, separate from the binds, which
// stay in the shell settings.

var DATA_VERSION = 1

// Mirrors Farm.DEFAULT_TAX_RATE (modules do not import each other).
var DEFAULT_TAX_RATE = 0.065

function defaultData() {
  return {
    version: DATA_VERSION,
    farm: { plots: [], cycles: [], settings: { taxRate: DEFAULT_TAX_RATE } },
    blackzone: { sets: [], events: [] }
  }
}

function listOr(value) {
  return Array.isArray(value) ? value : []
}

function taxRateOr(settings) {
  var rate = settings && typeof settings === "object" ? settings.taxRate : undefined
  return typeof rate === "number" && isFinite(rate) && rate >= 0 && rate <= 1 ? rate : DEFAULT_TAX_RATE
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
    settings: { taxRate: taxRateOr(farm.settings) }
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
