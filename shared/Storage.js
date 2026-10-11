.pragma library

// Tracker data (farm and black zone) lives in
// ~/.local/share/albion-companion/data.json, separate from the binds, which
// stay in the shell settings.

var DATA_VERSION = 1

function defaultData() {
  return {
    version: DATA_VERSION,
    farm: { plots: [], cycles: [] },
    blackzone: { sets: [], events: [] }
  }
}

function listOr(value) {
  return Array.isArray(value) ? value : []
}

// Parses the data file into { ok: true, data } or { ok: false, error }.
// Missing or wrongly typed sections fall back to their defaults.
function parseData(text) {
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
  return {
    ok: true,
    data: {
      version: DATA_VERSION,
      farm: { plots: listOr(farm.plots), cycles: listOr(farm.cycles) },
      blackzone: { sets: listOr(blackzone.sets), events: listOr(blackzone.events) }
    }
  }
}

function serializeData(data) {
  return JSON.stringify(data, null, 2) + "\n"
}
