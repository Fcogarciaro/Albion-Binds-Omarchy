.pragma library

// Market price prefill via the Albion Online Data Project. Pure helpers: the
// request itself runs in QML (Process + curl), and a failure never blocks
// logging because the user can always type the price.

var SERVERS = ["west", "east", "europe"]

var CITIES = [
  { value: "Caerleon", label: "Caerleon" },
  { value: "Bridgewatch", label: "Bridgewatch" },
  { value: "Lymhurst", label: "Lymhurst" },
  { value: "Martlock", label: "Martlock" },
  { value: "Fort Sterling", label: "Fort Sterling" },
  { value: "Thetford", label: "Thetford" },
  { value: "Brecilien", label: "Brecilien" }
]

function isSafeItemId(id) {
  return typeof id === "string" && /^[A-Za-z0-9_@]+$/.test(id)
}

function buildUrl(itemIds, city, server) {
  var host = SERVERS.indexOf(server) >= 0 ? server : "west"
  var ids = (itemIds || []).filter(isSafeItemId)
  return "https://" + host + ".albion-online-data.com/api/v2/stats/prices/" + ids.join(",")
    + "?locations=" + encodeURIComponent(city) + "&qualities=1"
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
