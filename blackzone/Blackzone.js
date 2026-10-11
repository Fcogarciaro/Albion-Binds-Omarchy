.pragma library

// Black zone profit tracker: gear sets, death and loot events, totals.
// Pure and immutable: every operation returns new data. Ids and timestamps
// are injected by the caller so results stay deterministic.
//
// Blackzone shape: { sets: [Set], events: [Event] }
// Set:   { id, name, pieces: [{ slot, base, tier, enchant, quality, quantity }] }
// Death: { id, type: "death", setId, setName, at, value, partial,
//          pieces: [{ itemId, quality, quantity, price|null }] }
//        Prices are a snapshot taken when the death is logged. The set name is
//        stored too, so deleting or renaming a set never rewrites history.
// Loot:  { id, type: "loot", at, value, note, tomes? }
//        tomes: { "<tier>": count } of untradeable tomes of insight; counted
//        only, never part of the silver value or the profit.
// Expense: { id, type: "expense", at, value (> 0), note }  (e.g. a paid portal)
// Operations return { ok: true, blackzone } or { ok: false, error }.

var SLOTS = [
  { value: "head", label: "Cabeza" },
  { value: "armor", label: "Pecho" },
  { value: "shoes", label: "Zapatos" },
  { value: "mainhand", label: "Arma principal" },
  { value: "offhand", label: "Arma secundaria" },
  { value: "cape", label: "Capa" },
  { value: "bag", label: "Bolsa" },
  { value: "mount", label: "Montura" },
  { value: "potion", label: "Poción" },
  { value: "food", label: "Comida" }
]

var MAX_SET_NAME = 40
var MAX_NOTE = 120
var MAX_QUANTITY = 999
var MIN_TIER = 1
var MAX_TIER = 8
var MAX_ENCHANT = 4
var MAX_QUALITY = 5
var MAX_TOMES = 999999

// Untradeable tomes of insight (T<n>_SKILLBOOK_NONTRADABLE), official ES-ES.
var TOME_TIERS = [
  { tier: 1, label: "principiante" }, { tier: 2, label: "novato" }, { tier: 3, label: "obrero" },
  { tier: 4, label: "iniciado" }, { tier: 5, label: "experto" }, { tier: 6, label: "maestro" },
  { tier: 7, label: "gran maestro" }, { tier: 8, label: "anciano" }
].map(function(t) { return { tier: t.tier, label: t.label, name: "Tomo de conocimiento del " + t.label } })

// { "<tier>": count } with valid tiers and positive integer counts only, or
// null when nothing is left.
function cleanTomes(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var out = {}
  var any = false
  for (var i = 0; i < TOME_TIERS.length; i++) {
    var tier = TOME_TIERS[i].tier
    var n = raw[tier]
    if (isNonNegativeInt(n) && n > 0 && n <= MAX_TOMES) { out[tier] = n; any = true }
  }
  return any ? out : null
}

function lootEvent(id, at, value, note, tomes) {
  var event = { id: id, type: "loot", at: at, value: value, note: note }
  var clean = cleanTomes(tomes)
  if (clean) event.tomes = clean
  return event
}

function isSlot(slot) {
  return SLOTS.some(function(s) { return s.value === slot })
}

function isConsumableSlot(slot) {
  return slot === "potion" || slot === "food"
}

function fail(error) {
  return { ok: false, error: error }
}

function isNonNegativeInt(v) {
  return typeof v === "number" && isFinite(v) && v >= 0 && Math.floor(v) === v
}

function isIntBetween(v, min, max) {
  return isNonNegativeInt(v) && v >= min && v <= max
}

function isSafeId(id) {
  return typeof id === "string" && /^[A-Za-z0-9_@]+$/.test(id)
}

function normalize(bz) {
  var b = bz && typeof bz === "object" ? bz : {}
  return {
    sets: Array.isArray(b.sets) ? b.sets : [],
    events: Array.isArray(b.events) ? b.events : []
  }
}

function withSets(bz, sets) {
  return { sets: sets, events: bz.events }
}

function withEvents(bz, events) {
  return { sets: bz.sets, events: events }
}

function findSet(bz, id) {
  for (var i = 0; i < bz.sets.length; i++) {
    if (bz.sets[i].id === id) return i
  }
  return -1
}

function hasId(list, id) {
  return list.some(function(x) { return x.id === id })
}

// ---------- Items ----------

// API item id: T<tier>_<base>, plus @<enchant> when enchanted.
function itemId(piece) {
  return "T" + piece.tier + "_" + piece.base + (piece.enchant > 0 ? "@" + piece.enchant : "")
}

// Key of one piece in a price map: "<itemId>:<quality>".
function priceKey(piece) {
  return itemId(piece) + ":" + piece.quality
}

// Distinct { itemId, quality } of a set, in piece order (for price requests).
function setItems(set) {
  var seen = {}
  var out = []
  var pieces = set && Array.isArray(set.pieces) ? set.pieces : []
  for (var i = 0; i < pieces.length; i++) {
    var key = priceKey(pieces[i])
    if (seen[key]) continue
    seen[key] = true
    out.push({ itemId: itemId(pieces[i]), quality: pieces[i].quality })
  }
  return out
}

// Valid piece, or null. Consumables are stacks of any quantity and ignore
// quality; gear is always a single piece.
function cleanPiece(raw, catalog) {
  if (!raw || typeof raw !== "object") return null
  if (!isSlot(raw.slot)) return null
  if (!isSafeId(raw.base)) return null
  if (!isIntBetween(raw.tier, MIN_TIER, MAX_TIER)) return null
  if (!isIntBetween(raw.enchant, 0, MAX_ENCHANT)) return null
  var consumable = isConsumableSlot(raw.slot)
  var quality = consumable ? 1 : raw.quality
  if (!isIntBetween(quality, 1, MAX_QUALITY)) return null
  var quantity = 1
  if (consumable && raw.quantity !== undefined) {
    if (!isIntBetween(raw.quantity, 1, MAX_QUANTITY)) return null
    quantity = raw.quantity
  }
  if (catalog) {
    var entry = null
    for (var i = 0; i < catalog.length; i++) {
      if (catalog[i].base === raw.base) { entry = catalog[i]; break }
    }
    if (!entry || entry.slot !== raw.slot || entry.tiers.indexOf(raw.tier) < 0) return null
  }
  return { slot: raw.slot, base: raw.base, tier: raw.tier, enchant: raw.enchant, quality: quality, quantity: quantity }
}

// ---------- Sanitizing ----------

function sanitizeSet(raw) {
  if (!raw || typeof raw !== "object") return null
  if (typeof raw.id !== "string" || raw.id === "") return null
  if (typeof raw.name !== "string") return null
  var name = raw.name.trim()
  if (name === "") return null
  var pieces = []
  var list = Array.isArray(raw.pieces) ? raw.pieces : []
  for (var i = 0; i < list.length; i++) {
    var piece = cleanPiece(list[i])
    if (piece) pieces.push(piece)
  }
  return { id: raw.id, name: name.slice(0, MAX_SET_NAME), pieces: pieces }
}

function sanitizeDeathPiece(raw) {
  if (!raw || typeof raw !== "object") return null
  if (!isSafeId(raw.itemId)) return null
  if (!isIntBetween(raw.quality, 1, MAX_QUALITY)) return null
  if (!isIntBetween(raw.quantity, 1, MAX_QUANTITY)) return null
  var price = raw.price === null || raw.price === undefined ? null : raw.price
  if (price !== null && !(isNonNegativeInt(price) && price > 0)) return null
  return { itemId: raw.itemId, quality: raw.quality, quantity: raw.quantity, price: price }
}

var DEFAULT_EXPENSE_NOTE = "Portal"

function expenseEvent(id, at, value, note) {
  var clean = typeof note === "string" ? note.trim().slice(0, MAX_NOTE) : ""
  return { id: id, type: "expense", at: at, value: value, note: clean === "" ? DEFAULT_EXPENSE_NOTE : clean }
}

function sanitizeEvent(raw) {
  if (!raw || typeof raw !== "object") return null
  if (typeof raw.id !== "string" || raw.id === "") return null
  if (!isNonNegativeInt(raw.at) || !isNonNegativeInt(raw.value)) return null
  if (raw.type === "loot") {
    return lootEvent(raw.id, raw.at, raw.value, typeof raw.note === "string" ? raw.note.trim().slice(0, MAX_NOTE) : "", raw.tomes)
  }
  if (raw.type === "expense") {
    return raw.value > 0 ? expenseEvent(raw.id, raw.at, raw.value, raw.note) : null
  }
  if (raw.type !== "death") return null
  if (typeof raw.setId !== "string" || raw.setId === "") return null
  if (typeof raw.setName !== "string" || raw.setName.trim() === "") return null
  if (!Array.isArray(raw.pieces)) return null
  var pieces = []
  for (var i = 0; i < raw.pieces.length; i++) {
    var piece = sanitizeDeathPiece(raw.pieces[i])
    if (!piece) return null
    pieces.push(piece)
  }
  return {
    id: raw.id, type: "death", setId: raw.setId, setName: raw.setName.trim().slice(0, MAX_SET_NAME), at: raw.at,
    value: raw.value, partial: isPartial(pieces), pieces: pieces
  }
}

function isPartial(pieces) {
  return pieces.some(function(p) { return p.price === null })
}

// Drops malformed sets, pieces and events plus duplicate ids. A death whose
// set was deleted is kept: it carries its own set name. Never throws.
function sanitizeBlackzone(raw) {
  var b = raw && typeof raw === "object" ? raw : {}
  var sets = []
  var setIds = {}
  var list = Array.isArray(b.sets) ? b.sets : []
  for (var i = 0; i < list.length; i++) {
    var set = sanitizeSet(list[i])
    if (!set || setIds[set.id]) continue
    setIds[set.id] = true
    sets.push(set)
  }
  var events = []
  var eventIds = {}
  var eventsRaw = Array.isArray(b.events) ? b.events : []
  for (var j = 0; j < eventsRaw.length; j++) {
    var event = sanitizeEvent(eventsRaw[j])
    if (!event || eventIds[event.id]) continue
    eventIds[event.id] = true
    events.push(event)
  }
  return { sets: sets, events: events }
}

// ---------- Set operations ----------

function validateSetName(bz, name, exceptId) {
  var clean = String(name === undefined || name === null ? "" : name).trim()
  if (clean === "") return { error: "Escribe un nombre para el set." }
  if (clean.length > MAX_SET_NAME) return { error: "El nombre del set es muy largo (máx. " + MAX_SET_NAME + ")." }
  var lower = clean.toLowerCase()
  if (bz.sets.some(function(s) { return s.id !== exceptId && s.name.toLowerCase() === lower }))
    return { error: "Ya existe un set con ese nombre." }
  return { name: clean }
}

function addSet(blackzone, name, id) {
  var bz = normalize(blackzone)
  var checked = validateSetName(bz, name, null)
  if (checked.error) return fail(checked.error)
  if (typeof id !== "string" || id === "" || hasId(bz.sets, id)) return fail("No pude crear el set (id no válido).")
  return { ok: true, blackzone: withSets(bz, bz.sets.concat([{ id: id, name: checked.name, pieces: [] }])) }
}

function renameSet(blackzone, setId, name) {
  var bz = normalize(blackzone)
  var index = findSet(bz, setId)
  if (index < 0) return fail("No encontré ese set.")
  var checked = validateSetName(bz, name, setId)
  if (checked.error) return fail(checked.error)
  var sets = bz.sets.slice()
  sets[index] = { id: sets[index].id, name: checked.name, pieces: sets[index].pieces }
  return { ok: true, blackzone: withSets(bz, sets) }
}

// Deletes the set only: logged deaths keep their snapshot and set name.
function removeSet(blackzone, setId) {
  var bz = normalize(blackzone)
  if (findSet(bz, setId) < 0) return fail("No encontré ese set.")
  return { ok: true, blackzone: withSets(bz, bz.sets.filter(function(s) { return s.id !== setId })) }
}

// input: { slot, base, tier, enchant, quality, quantity }; catalog (optional)
// restricts base, slot and tier to known items.
function addPiece(blackzone, setId, input, catalog) {
  var bz = normalize(blackzone)
  var index = findSet(bz, setId)
  if (index < 0) return fail("No encontré ese set.")
  var piece = cleanPiece(input, catalog)
  if (!piece) return fail("La pieza no es válida (revisa ranura, tier, encantamiento, calidad y cantidad).")
  var sets = bz.sets.slice()
  sets[index] = { id: sets[index].id, name: sets[index].name, pieces: sets[index].pieces.concat([piece]) }
  return { ok: true, blackzone: withSets(bz, sets) }
}

function removePiece(blackzone, setId, pieceIndex) {
  var bz = normalize(blackzone)
  var index = findSet(bz, setId)
  if (index < 0) return fail("No encontré ese set.")
  var pieces = bz.sets[index].pieces
  if (!isNonNegativeInt(pieceIndex) || pieceIndex >= pieces.length) return fail("No encontré esa pieza.")
  var sets = bz.sets.slice()
  sets[index] = {
    id: sets[index].id, name: sets[index].name,
    pieces: pieces.filter(function(p, i) { return i !== pieceIndex })
  }
  return { ok: true, blackzone: withSets(bz, sets) }
}

// ---------- Events ----------

function validEventBase(bz, input) {
  if (!isNonNegativeInt(input.now)) return "No pude registrar la fecha."
  if (typeof input.id !== "string" || input.id === "" || hasId(bz.events, input.id)) return "No pude crear el registro (id no válido)."
  return null
}

function priceOf(prices, key) {
  var p = prices && typeof prices === "object" ? prices[key] : null
  return isNonNegativeInt(p) && p > 0 ? p : null
}

// input: { setId, now, id, prices: { "<itemId>:<quality>": price|null }, value? }
// value (optional) overrides the computed total (price x quantity of the
// priced pieces); it is typed by the user when some prices are missing.
function logDeath(blackzone, input) {
  var bz = normalize(blackzone)
  var i = input || {}
  var index = findSet(bz, i.setId)
  if (index < 0) return fail("Elige un set.")
  var set = bz.sets[index]
  if (set.pieces.length === 0) return fail("Ese set no tiene piezas.")
  var baseError = validEventBase(bz, i)
  if (baseError) return fail(baseError)
  if (i.value !== undefined && i.value !== null && !isNonNegativeInt(i.value))
    return fail("El valor perdido debe ser un número entero (0 o más).")
  var pieces = set.pieces.map(function(p) {
    return { itemId: itemId(p), quality: p.quality, quantity: p.quantity, price: priceOf(i.prices, priceKey(p)) }
  })
  var computed = pieces.reduce(function(sum, p) { return sum + (p.price === null ? 0 : p.price * p.quantity) }, 0)
  var event = {
    id: i.id, type: "death", setId: set.id, setName: set.name, at: i.now,
    value: i.value === undefined || i.value === null ? computed : i.value,
    partial: isPartial(pieces), pieces: pieces
  }
  return { ok: true, blackzone: withEvents(bz, bz.events.concat([event])) }
}

// input: { value, note?, tomes?, now, id }. The value may be 0 (tomes only).
function logLoot(blackzone, input) {
  var bz = normalize(blackzone)
  var i = input || {}
  if (!isNonNegativeInt(i.value)) return fail("El valor del botín debe ser un número entero (0 o más).")
  var baseError = validEventBase(bz, i)
  if (baseError) return fail(baseError)
  var note = typeof i.note === "string" ? i.note.trim().slice(0, MAX_NOTE) : ""
  return { ok: true, blackzone: withEvents(bz, bz.events.concat([lootEvent(i.id, i.now, i.value, note, i.tomes)])) }
}

// input: { value (> 0), note?, now, id }. An empty note is stored as "Portal".
function logExpense(blackzone, input) {
  var bz = normalize(blackzone)
  var i = input || {}
  if (!isNonNegativeInt(i.value) || i.value <= 0) return fail("El gasto debe ser un número entero mayor que 0.")
  var baseError = validEventBase(bz, i)
  if (baseError) return fail(baseError)
  return { ok: true, blackzone: withEvents(bz, bz.events.concat([expenseEvent(i.id, i.now, i.value, i.note)])) }
}

function removeEvent(blackzone, eventId) {
  var bz = normalize(blackzone)
  if (!hasId(bz.events, eventId)) return fail("No encontré ese registro.")
  return { ok: true, blackzone: withEvents(bz, bz.events.filter(function(e) { return e.id !== eventId })) }
}

// ---------- Queries ----------

// Profit = loot - losses - expenses (spent). bySet counts deaths per set id (removed sets keep
// the name stored in their deaths). tomes counts insight tomes per tier
// (no silver value). lootPerDeath is null without deaths.
function totals(blackzone) {
  var bz = normalize(blackzone)
  var result = { loot: 0, lost: 0, profit: 0, deaths: 0, loots: 0, bySet: {}, lootPerDeath: null, tomes: {}, tomeCount: 0, spent: 0, expenses: 0 }
  for (var i = 0; i < bz.events.length; i++) {
    var e = bz.events[i]
    if (e.type === "loot") {
      result.loot += e.value
      result.loots += 1
      for (var tier in e.tomes) {
        result.tomes[tier] = (result.tomes[tier] || 0) + e.tomes[tier]
        result.tomeCount += e.tomes[tier]
      }
    } else if (e.type === "expense") {
      result.spent += e.value
      result.expenses += 1
    } else if (e.type === "death") {
      result.lost += e.value
      result.deaths += 1
      if (!result.bySet[e.setId]) result.bySet[e.setId] = { name: e.setName, deaths: 0, lost: 0 }
      result.bySet[e.setId].deaths += 1
      result.bySet[e.setId].lost += e.value
    }
  }
  result.profit = result.loot - result.lost - result.spent
  if (result.deaths > 0) result.lootPerDeath = Math.round(result.loot / result.deaths)
  return result
}

// Events newest first; limit (optional) caps the result.
function recentEvents(blackzone, limit) {
  var events = normalize(blackzone).events.slice()
  events.sort(function(a, b) { return b.at - a.at })
  return limit > 0 ? events.slice(0, limit) : events
}

// Official name of a piece at a tier: the catalog entry's per-tier name, then
// its generic name, then the fallback (the base id) when the entry is unknown.
function pieceName(entry, tier, fallback) {
  if (!entry) return fallback || ""
  return entry.names && entry.names[tier] ? entry.names[tier] : entry.nameEs
}

// Search options for a slot: one per (base, tier), labelled with the game's
// full name for that tier. value is "<base>:<tier>" (see parsePieceOption).
function pieceOptions(catalog, slot) {
  var out = []
  var list = Array.isArray(catalog) ? catalog : []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (entry.slot !== slot) continue
    for (var j = 0; j < entry.tiers.length; j++) {
      var tier = entry.tiers[j]
      out.push({ value: entry.base + ":" + tier, label: pieceName(entry, tier), description: "T" + tier })
    }
  }
  return out
}

// "<base>:<tier>" -> { base, tier }, or null when malformed.
function parsePieceOption(value) {
  if (typeof value !== "string") return null
  var m = /^(.+):(\d)$/.exec(value)
  if (!m) return null
  var tier = Number(m[2])
  return tier >= MIN_TIER && tier <= MAX_TIER ? { base: m[1], tier: tier } : null
}
