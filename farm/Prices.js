.pragma library

// Market price prefill via the Albion Online Data Project. Pure helpers: the
// request itself runs in QML (Process + curl), and a failure never blocks
// logging because the user can always type the price.

var SERVERS = ["west", "east", "europe"]

// Labels for the server selector (values are SERVERS).
var SERVER_OPTIONS = [
  { value: "west", label: "América" },
  { value: "east", label: "Asia" },
  { value: "europe", label: "Europa" }
]

var CITIES = [
  { value: "Caerleon", label: "Caerleon" },
  { value: "Bridgewatch", label: "Bridgewatch" },
  { value: "Lymhurst", label: "Lymhurst" },
  { value: "Martlock", label: "Martlock" },
  { value: "Fort Sterling", label: "Fort Sterling" },
  { value: "Thetford", label: "Thetford" },
  { value: "Brecilien", label: "Brecilien" }
]

var THROTTLED_MESSAGE = "El mercado limitó las consultas, intenta en un minuto."

// curl arguments for one price request. The API throttles uncompressed
// requests (HTTP 429), so --compressed is required. No -f: the HTTP status is
// appended after the body (-w) and read by checkResponse instead.
function curlArgs(url, timeoutSeconds) {
  return ["curl", "-sS", "--compressed", "--max-time", String(timeoutSeconds), "-w", "\n%{http_code}", url]
}

// Splits curl's stdout (body, newline, status code). Returns { ok: true, body }
// for a 2xx answer, otherwise { ok: false, error }: the throttling message for
// HTTP 429, genericError for anything else (including no answer at all).
function checkResponse(text, genericError) {
  var raw = typeof text === "string" ? text : ""
  var cut = raw.lastIndexOf("\n")
  var status = cut >= 0 ? parseInt(raw.slice(cut + 1), 10) : 0
  if (status === 429) return { ok: false, error: THROTTLED_MESSAGE }
  if (!(status >= 200 && status < 300)) return { ok: false, error: genericError }
  return { ok: true, body: raw.slice(0, cut) }
}

// True when two request descriptors (city, server, plot, crop...) are the
// same, so an answer can be applied only to the request it was made for.
function sameRequest(a, b) {
  if (!a || !b) return false
  var keys = Object.keys(a)
  if (keys.length !== Object.keys(b).length) return false
  for (var i = 0; i < keys.length; i++) {
    if (a[keys[i]] !== b[keys[i]]) return false
  }
  return true
}

function isSafeItemId(id) {
  return typeof id === "string" && /^[A-Za-z0-9_@]+$/.test(id)
}

// qualities (optional): API qualities 1..5 to request; defaults to [1].
function buildUrl(itemIds, city, server, qualities) {
  var host = SERVERS.indexOf(server) >= 0 ? server : "west"
  var ids = (itemIds || []).filter(isSafeItemId)
  var wanted = (qualities || []).filter(function(q) { return typeof q === "number" && q >= 1 && q <= 5 && Math.floor(q) === q })
  return "https://" + host + ".albion-online-data.com/api/v2/stats/prices/" + ids.join(",")
    + "?locations=" + encodeURIComponent(city) + "&qualities=" + (wanted.length > 0 ? wanted.join(",") : "1")
}

// Parses the API response into { ok: true, prices: { itemId: price|null } }
// for the given city, or { ok: false, error }. A price of 0 means "no data"
// and becomes null. wantedIds (optional) are added as null when absent.
function parsePrices(jsonText, city, wantedIds) {
  var raw
  try {
    raw = JSON.parse(jsonText)
  } catch (e) {
    return { ok: false, error: "No pude leer los precios del mercado." }
  }
  if (!Array.isArray(raw)) return { ok: false, error: "Respuesta inesperada del mercado." }

  var prices = {}
  for (var i = 0; i < raw.length; i++) {
    var entry = raw[i]
    if (!entry || typeof entry !== "object" || typeof entry.item_id !== "string") continue
    if (entry.city !== city) continue
    var price = typeof entry.sell_price_min === "number" && entry.sell_price_min > 0 ? entry.sell_price_min : null
    var known = prices[entry.item_id]
    if (known === undefined || (price !== null && (known === null || price < known)))
      prices[entry.item_id] = price
  }
  var wanted = wantedIds || []
  for (var j = 0; j < wanted.length; j++) {
    if (prices[wanted[j]] === undefined) prices[wanted[j]] = null
  }
  return { ok: true, prices: prices }
}

// Like parsePrices, but keyed by "<itemId>:<quality>" so one item can carry
// a price per quality. wantedKeys (optional) are added as null when absent.
function parseQualityPrices(jsonText, city, wantedKeys) {
  var raw
  try {
    raw = JSON.parse(jsonText)
  } catch (e) {
    return { ok: false, error: "No pude leer los precios del mercado." }
  }
  if (!Array.isArray(raw)) return { ok: false, error: "Respuesta inesperada del mercado." }

  var prices = {}
  for (var i = 0; i < raw.length; i++) {
    var entry = raw[i]
    if (!entry || typeof entry !== "object" || typeof entry.item_id !== "string") continue
    if (entry.city !== city || typeof entry.quality !== "number") continue
    var key = entry.item_id + ":" + entry.quality
    var price = typeof entry.sell_price_min === "number" && entry.sell_price_min > 0 ? entry.sell_price_min : null
    var known = prices[key]
    if (known === undefined || (price !== null && (known === null || price < known)))
      prices[key] = price
  }
  var wanted = wantedKeys || []
  for (var j = 0; j < wanted.length; j++) {
    if (prices[wanted[j]] === undefined) prices[wanted[j]] = null
  }
  return { ok: true, prices: prices }
}
