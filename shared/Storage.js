.pragma library

// Tracker data (farm and black zone) lives in
// ~/.local/share/albion-companion/data.json, separate from the binds, which
// stay in the shell settings.

var DATA_VERSION = 1

// Mirror Farm.js defaults (modules do not import each other).
var DEFAULT_TAX_RATE = 0.065
var DEFAULT_SEEDS_PER_PLOT = 9
var MAX_SEEDS_PER_PLOT = 1000
var DEFAULT_CITY = "Lymhurst"
var MAX_UI_ID = 64
var MAX_UI_NOTE = 120
// Last open tab of the bar panel / large window (the window has no "binds").
var UI_TABS = ["binds", "farm", "blackzone"]
// Mirror Prices.js SERVERS; "west" is the default price server.
var UI_SERVERS = ["west", "east", "europe"]

function defaultData() {
  return {
    version: DATA_VERSION,
    farm: { plots: [], cycles: [], settings: settingsOr(null) },
    blackzone: { sets: [], events: [] },
    ui: uiOr(null)
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

// Remembered choices (last city, price server, death set, expense note and open tab). They live
// in the data file so they follow the user across PCs; every field is
// validated on its own and unknown keys are dropped.
function uiOr(ui) {
  var u = ui && typeof ui === "object" && !Array.isArray(ui) ? ui : {}
  var city = typeof u.city === "string" ? u.city.trim() : ""
  var setId = typeof u.deathSetId === "string" ? u.deathSetId : ""
  var note = typeof u.expenseNote === "string" ? u.expenseNote.trim() : ""
  return {
    city: city !== "" && city.length <= 40 ? city : DEFAULT_CITY,
    deathSetId: setId.length <= MAX_UI_ID ? setId : "",
    expenseNote: note.slice(0, MAX_UI_NOTE),
    tab: UI_TABS.indexOf(u.tab) >= 0 ? u.tab : "binds",
    server: UI_SERVERS.indexOf(u.server) >= 0 ? u.server : "west"
  }
}

// Parses the data file into { ok: true, data } or { ok: false, error }.
// Missing or wrongly typed sections fall back to their defaults.
// sanitizeFarm (optional, e.g. Farm.sanitizeFarm) cleans farm plots/cycles;
// sanitizeBlackzone (optional, e.g. Blackzone.sanitizeBlackzone) does the same
// for the black zone sets and events. Both are injected because modules do
// not import each other.
function parseData(text, sanitizeFarm, sanitizeBlackzone) {
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
  var blackzoneData = { sets: listOr(blackzone.sets), events: listOr(blackzone.events) }
  if (typeof sanitizeBlackzone === "function") blackzoneData = sanitizeBlackzone(blackzoneData)
  return {
    ok: true,
    data: {
      version: DATA_VERSION,
      farm: farmData,
      blackzone: blackzoneData,
      ui: uiOr(raw.ui)
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
function reloadOutcome(text, lastWritten, current, sanitizeFarm, sanitizeBlackzone) {
  if (text === lastWritten) return { action: "same" }
  var result = parseData(text, sanitizeFarm, sanitizeBlackzone)
  if (!result.ok) return { action: "error", error: result.error }
  if (serializeData(result.data) === serializeData(current)) return { action: "same" }
  return { action: "apply", data: result.data }
}

// What saveData() should do. "queue": the first load has not finished, so
// the document is still the defaults and writing would clobber the real file.
// "block": the first load found a file it could not parse; saves stay off
// until a later reload succeeds. "write" otherwise.
function saveDecision(state) {
  if (!state.loaded) return "queue"
  if (state.loadBlocked) return "block"
  return "write"
}

// The error text to show after a successful save: a save error clears, but a
// load or parse error stays.
function errorAfterSave(error, saveFailed) {
  return saveFailed ? "" : error
}
