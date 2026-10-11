import { test } from "node:test"
import assert from "node:assert/strict"
import { loadBlackzone, plain } from "./helpers/load-model.mjs"

const Bz = loadBlackzone()

const empty = () => ({ sets: [], events: [] })
const ok = (r) => { assert.equal(r.ok, true, r.error); return plain(r.blackzone) }
const helm = { slot: "head", base: "HEAD_PLATE_SET1", tier: 6, enchant: 2, quality: 3 }
const potion = { slot: "potion", base: "POTION_HEAL", tier: 5, enchant: 0, quality: 4, quantity: 5 }

function withSet() {
  let bz = ok(Bz.addSet(empty(), "Tanque", "s1"))
  bz = ok(Bz.addPiece(bz, "s1", helm))
  return ok(Bz.addPiece(bz, "s1", potion))
}

test("SLOTS: eight gear slots plus potion and food, with Spanish labels", () => {
  const slots = plain(Bz.SLOTS)
  assert.deepEqual(slots.map((s) => s.value), ["head", "armor", "shoes", "mainhand", "offhand", "cape", "bag", "mount", "potion", "food"])
  assert.deepEqual(slots.map((s) => s.label), [
    "Cabeza", "Pecho", "Zapatos", "Arma principal", "Arma secundaria", "Capa", "Bolsa", "Montura", "Poción", "Comida"
  ])
  assert.equal(slots.find((s) => s.value === "food").label, "Comida")
  assert.equal(Bz.isConsumableSlot("potion"), true)
  assert.equal(Bz.isConsumableSlot("head"), false)
})

test("itemId: tier prefix and enchant suffix only when enchanted", () => {
  assert.equal(Bz.itemId({ base: "HEAD_PLATE_SET1", tier: 6, enchant: 2 }), "T6_HEAD_PLATE_SET1@2")
  assert.equal(Bz.itemId({ base: "2H_BOW", tier: 4, enchant: 0 }), "T4_2H_BOW")
})

test("addSet: trims, rejects empty, long, duplicate names and bad ids", () => {
  const bz = ok(Bz.addSet(empty(), "  Tanque  ", "s1"))
  assert.deepEqual(bz.sets, [{ id: "s1", name: "Tanque", pieces: [] }])
  assert.equal(Bz.addSet(bz, "", "s2").ok, false)
  assert.equal(Bz.addSet(bz, "x".repeat(41), "s2").ok, false)
  assert.equal(Bz.addSet(bz, "tanque", "s2").ok, false)
  assert.equal(Bz.addSet(bz, "Otro", "s1").ok, false)
  assert.equal(Bz.addSet(bz, "Otro", "").ok, false)
})

test("renameSet: validates like addSet, may keep its own name", () => {
  let bz = ok(Bz.addSet(empty(), "A", "s1"))
  bz = ok(Bz.addSet(bz, "B", "s2"))
  assert.equal(ok(Bz.renameSet(bz, "s1", "A2")).sets[0].name, "A2")
  assert.equal(ok(Bz.renameSet(bz, "s1", "a")).sets[0].name, "a")
  assert.equal(Bz.renameSet(bz, "s1", "B").ok, false)
  assert.equal(Bz.renameSet(bz, "s1", "  ").ok, false)
  assert.equal(Bz.renameSet(bz, "nope", "C").ok, false)
})

test("addPiece: gear keeps quantity 1, consumables keep quantity and quality 1", () => {
  const bz = withSet()
  assert.deepEqual(bz.sets[0].pieces[0], { slot: "head", base: "HEAD_PLATE_SET1", tier: 6, enchant: 2, quality: 3, quantity: 1 })
  assert.deepEqual(bz.sets[0].pieces[1], { slot: "potion", base: "POTION_HEAL", tier: 5, enchant: 0, quality: 1, quantity: 5 })
  const gear = ok(Bz.addPiece(empty().sets.length ? empty() : ok(Bz.addSet(empty(), "S", "s1")), "s1", { ...helm, quantity: 9 }))
  assert.equal(gear.sets[0].pieces[0].quantity, 1)
  const defaulted = ok(Bz.addPiece(ok(Bz.addSet(empty(), "S", "s1")), "s1", { slot: "food", base: "MEAL_SOUP", tier: 3, enchant: 0 }))
  assert.equal(defaulted.sets[0].pieces[0].quantity, 1)
})

test("addPiece: rejects invalid input", () => {
  const bz = ok(Bz.addSet(empty(), "S", "s1"))
  const bad = [
    { ...helm, slot: "wings" }, { ...helm, base: "a/b" }, { ...helm, base: "" }, { ...helm, tier: 0 }, { ...helm, tier: 9 },
    { ...helm, enchant: 5 }, { ...helm, enchant: -1 }, { ...helm, quality: 0 }, { ...helm, quality: 6 },
    { ...potion, quantity: 0 }, { ...potion, quantity: 1.5 }, { ...potion, quantity: 10000 }, { ...helm, tier: "6" }
  ]
  for (const piece of bad) assert.equal(Bz.addPiece(bz, "s1", piece).ok, false, JSON.stringify(piece))
  assert.equal(Bz.addPiece(bz, "nope", helm).ok, false)
})

test("addPiece: optional catalog validates base, slot and tier", () => {
  const bz = ok(Bz.addSet(empty(), "S", "s1"))
  const catalog = [{ base: "HEAD_PLATE_SET1", slot: "head", nameEs: "Casco", tiers: [4, 5, 6] }]
  assert.equal(Bz.addPiece(bz, "s1", helm, catalog).ok, true)
  assert.equal(Bz.addPiece(bz, "s1", { ...helm, tier: 8 }, catalog).ok, false)
  assert.equal(Bz.addPiece(bz, "s1", { ...helm, slot: "armor" }, catalog).ok, false)
  assert.equal(Bz.addPiece(bz, "s1", { ...helm, base: "HEAD_X" }, catalog).ok, false)
})

test("removePiece: by index; bad index or set is an error", () => {
  const bz = withSet()
  const next = ok(Bz.removePiece(bz, "s1", 0))
  assert.deepEqual(next.sets[0].pieces.map((p) => p.base), ["POTION_HEAL"])
  assert.equal(Bz.removePiece(bz, "s1", 5).ok, false)
  assert.equal(Bz.removePiece(bz, "s1", -1).ok, false)
  assert.equal(Bz.removePiece(bz, "nope", 0).ok, false)
  assert.equal(bz.sets[0].pieces.length, 2)
})

test("setPriceKeys / priceKey: one request id per distinct piece", () => {
  const set = withSet().sets[0]
  assert.equal(Bz.priceKey(set.pieces[0]), "T6_HEAD_PLATE_SET1@2:3")
  assert.equal(Bz.priceKey(set.pieces[1]), "T5_POTION_HEAL:1")
  assert.deepEqual(plain(Bz.setItems(set)), [
    { itemId: "T6_HEAD_PLATE_SET1@2", quality: 3 }, { itemId: "T5_POTION_HEAL", quality: 1 }
  ])
})

test("logDeath: snapshots prices, value = sum of price x quantity", () => {
  const bz = withSet()
  const prices = { "T6_HEAD_PLATE_SET1@2:3": 10000, "T5_POTION_HEAL:1": 200 }
  const next = ok(Bz.logDeath(bz, { setId: "s1", now: 1000, id: "e1", prices }))
  assert.deepEqual(next.events, [{
    id: "e1", type: "death", setId: "s1", setName: "Tanque", at: 1000, value: 11000, partial: false,
    pieces: [
      { itemId: "T6_HEAD_PLATE_SET1@2", quality: 3, quantity: 1, price: 10000 },
      { itemId: "T5_POTION_HEAL", quality: 1, quantity: 5, price: 200 }
    ]
  }])
})

test("logDeath: missing price makes it partial; value stays editable", () => {
  const bz = withSet()
  const partial = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: { "T6_HEAD_PLATE_SET1@2:3": 10000 } }))
  assert.equal(partial.events[0].partial, true)
  assert.equal(partial.events[0].value, 10000)
  assert.equal(partial.events[0].pieces[1].price, null)
  const edited = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e2", prices: {}, value: 50000 }))
  assert.equal(edited.events[0].value, 50000)
  assert.equal(edited.events[0].partial, true)
})

test("logDeath: validates set, value, time and id", () => {
  const bz = withSet()
  const base = { setId: "s1", now: 1, id: "e1", prices: {} }
  assert.equal(Bz.logDeath(bz, { ...base, setId: "x" }).ok, false)
  assert.equal(Bz.logDeath(bz, { ...base, value: -1 }).ok, false)
  assert.equal(Bz.logDeath(bz, { ...base, value: 1.5 }).ok, false)
  assert.equal(Bz.logDeath(bz, { ...base, now: -1 }).ok, false)
  assert.equal(Bz.logDeath(bz, { ...base, id: "" }).ok, false)
  const logged = ok(Bz.logDeath(bz, base))
  assert.equal(Bz.logDeath(logged, base).ok, false)
  const emptySet = ok(Bz.addSet(empty(), "Vacío", "s2"))
  assert.equal(Bz.logDeath(emptySet, { ...base, setId: "s2" }).ok, false)
})

test("logDeath: ignores bad prices (non-integers, zero) as missing", () => {
  const bz = withSet()
  const next = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: { "T6_HEAD_PLATE_SET1@2:3": 0, "T5_POTION_HEAL:1": "x" } }))
  assert.deepEqual(next.events[0].pieces.map((p) => p.price), [null, null])
  assert.equal(next.events[0].value, 0)
})

test("logLoot: value and optional note", () => {
  let bz = ok(Bz.logLoot(empty(), { value: 250000, note: "  cofre azul ", now: 5, id: "l1" }))
  assert.deepEqual(bz.events, [{ id: "l1", type: "loot", at: 5, value: 250000, note: "cofre azul" }])
  bz = ok(Bz.logLoot(bz, { value: 0, now: 6, id: "l2" }))
  assert.equal(bz.events[1].note, "")
  for (const bad of [{ value: -5 }, { value: "x" }, { value: 1.5 }, { value: 1, id: "" }, { value: 1, now: -1 }])
    assert.equal(Bz.logLoot(empty(), { now: 1, id: "l9", ...bad }).ok, false, JSON.stringify(bad))
  assert.equal(Bz.logLoot(bz, { value: 1, now: 1, id: "l1" }).ok, false)
  assert.equal(ok(Bz.logLoot(empty(), { value: 1, note: "n".repeat(300), now: 1, id: "l" })).events[0].note.length, 120)
})

test("removeEvent: deletes death or loot; unknown id is an error", () => {
  let bz = withSet()
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: {} }))
  bz = ok(Bz.logLoot(bz, { value: 10, now: 2, id: "l1" }))
  assert.deepEqual(ok(Bz.removeEvent(bz, "e1")).events.map((e) => e.id), ["l1"])
  assert.equal(Bz.removeEvent(bz, "nope").ok, false)
})

test("removeSet: set goes away, its deaths stay with the snapshot name", () => {
  let bz = withSet()
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: { "T6_HEAD_PLATE_SET1@2:3": 100 } }))
  const next = ok(Bz.removeSet(bz, "s1"))
  assert.deepEqual(next.sets, [])
  assert.equal(next.events.length, 1)
  assert.equal(next.events[0].setName, "Tanque")
  assert.equal(Bz.removeSet(next, "s1").ok, false)
})

test("renameSet: past deaths keep the name they were logged with", () => {
  let bz = withSet()
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: {} }))
  bz = ok(Bz.renameSet(bz, "s1", "Nuevo"))
  assert.equal(bz.events[0].setName, "Tanque")
})

test("totals: loot, losses, profit, deaths and per-set losses (including removed sets)", () => {
  let bz = withSet()
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: {}, value: 30000 }))
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 2, id: "e2", prices: {}, value: 10000 }))
  bz = ok(Bz.logLoot(bz, { value: 100000, now: 3, id: "l1" }))
  bz = ok(Bz.logLoot(bz, { value: 20000, now: 4, id: "l2" }))
  bz = ok(Bz.removeSet(bz, "s1"))
  const t = plain(Bz.totals(bz))
  assert.equal(t.loot, 120000)
  assert.equal(t.lost, 40000)
  assert.equal(t.profit, 80000)
  assert.equal(t.deaths, 2)
  assert.equal(t.loots, 2)
  assert.deepEqual(t.bySet, { s1: { name: "Tanque", deaths: 2, lost: 40000 } })
  assert.equal(t.lootPerDeath, 60000)
  assert.deepEqual(plain(Bz.totals(empty())), { loot: 0, lost: 0, profit: 0, deaths: 0, loots: 0, bySet: {}, lootPerDeath: null, tomes: {}, tomeCount: 0 })
})

test("recentEvents: newest first with an optional limit", () => {
  let bz = ok(Bz.logLoot(empty(), { value: 1, now: 1, id: "a" }))
  bz = ok(Bz.logLoot(bz, { value: 1, now: 3, id: "b" }))
  bz = ok(Bz.logLoot(bz, { value: 1, now: 2, id: "c" }))
  assert.deepEqual(plain(Bz.recentEvents(bz)).map((e) => e.id), ["b", "c", "a"])
  assert.deepEqual(plain(Bz.recentEvents(bz, 2)).map((e) => e.id), ["b", "c"])
})

test("sanitizeBlackzone: keeps valid data unchanged", () => {
  let bz = withSet()
  bz = ok(Bz.logDeath(bz, { setId: "s1", now: 1, id: "e1", prices: { "T6_HEAD_PLATE_SET1@2:3": 100 } }))
  bz = ok(Bz.logLoot(bz, { value: 5, note: "x", now: 2, id: "l1" }))
  assert.deepEqual(plain(Bz.sanitizeBlackzone(bz)), bz)
})

test("sanitizeBlackzone: drops malformed sets, pieces, events and duplicate ids; never throws", () => {
  const raw = {
    sets: [
      null, 3, { id: "", name: "x", pieces: [] }, { id: "a", name: "  ", pieces: [] },
      { id: "s1", name: "Tanque", pieces: [helm, { slot: "wings" }, null, { ...helm, quality: 9 }, { ...potion, quantity: 0 }] },
      { id: "s1", name: "Duplicado", pieces: [] },
      { id: "s2", name: "Sin piezas", pieces: "x" }
    ],
    events: [
      null, "x", { id: "d1", type: "death", setId: "s1", setName: "Tanque", at: 1, value: 10, pieces: [{ itemId: "T6_X", quality: 1, quantity: 1, price: null }] },
      { id: "d1", type: "loot", at: 2, value: 5, note: "" },
      { id: "d2", type: "death", setId: "s1", setName: "Tanque", at: 1, value: -1, pieces: [] },
      { id: "d3", type: "death", setId: "s1", at: 1, value: 1, pieces: [] },
      { id: "d4", type: "death", setId: "s1", setName: "T", at: 1, value: 1, pieces: [{ itemId: "bad id", quality: 1, quantity: 1, price: 5 }] },
      { id: "l1", type: "loot", at: 2, value: 5 },
      { id: "l2", type: "loot", at: 2, value: "5", note: "" },
      { id: "z", type: "other", at: 1, value: 1 }
    ]
  }
  const clean = plain(Bz.sanitizeBlackzone(raw))
  assert.deepEqual(clean.sets.map((s) => s.id), ["s1", "s2"])
  assert.deepEqual(clean.sets[0].pieces, [{ ...helm, quantity: 1 }])
  assert.deepEqual(clean.sets[1].pieces, [])
  assert.deepEqual(clean.events.map((e) => e.id), ["d1", "l1"])
  assert.equal(clean.events[0].partial, true)
  assert.equal(clean.events[1].note, "")
  for (const junk of [null, undefined, 5, "x", [], { sets: 3, events: "x" }])
    assert.deepEqual(plain(Bz.sanitizeBlackzone(junk)), { sets: [], events: [] })
})

test("sanitizeBlackzone: a death of a removed set is kept (setId need not exist)", () => {
  const clean = plain(Bz.sanitizeBlackzone({
    sets: [],
    events: [{ id: "d1", type: "death", setId: "gone", setName: "Viejo", at: 1, value: 10, pieces: [] }]
  }))
  assert.equal(clean.events.length, 1)
})

const catalog = [
  { base: "BAG", slot: "bag", nameEs: "Bolsa", tiers: [4, 5], names: { 4: "Bolsa del iniciado", 5: "Bolsa del experto" } },
  { base: "CAPE", slot: "cape", nameEs: "Capa", tiers: [4], names: { 4: "Capa del iniciado" } },
  { base: "POTION_POISON", slot: "potion", nameEs: "Poción de veneno", tiers: [3, 5],
    names: { 3: "Poción de veneno menor", 5: "Poción de veneno" } },
  { base: "OLD", slot: "bag", nameEs: "Vieja", tiers: [6] }
]

test("pieceOptions: one option per base and tier with the official name", () => {
  const opts = plain(Bz.pieceOptions(catalog, "bag"))
  assert.deepEqual(opts, [
    { value: "BAG:4", label: "Bolsa del iniciado", description: "T4" },
    { value: "BAG:5", label: "Bolsa del experto", description: "T5" },
    { value: "OLD:6", label: "Vieja", description: "T6" }
  ])
  assert.deepEqual(plain(Bz.pieceOptions(catalog, "potion")).map((o) => o.label), ["Poción de veneno menor", "Poción de veneno"])
  assert.deepEqual(plain(Bz.pieceOptions(catalog, "food")), [])
})

test("parsePieceOption: splits base and tier, rejects garbage", () => {
  assert.deepEqual(plain(Bz.parsePieceOption("BAG:4")), { base: "BAG", tier: 4 })
  assert.deepEqual(plain(Bz.parsePieceOption("2H_BOW:8")), { base: "2H_BOW", tier: 8 })
  for (const bad of ["", "BAG", "BAG:", ":4", "BAG:x", "BAG:0", "BAG:9", null, undefined]) {
    assert.equal(Bz.parsePieceOption(bad), null, String(bad))
  }
})

test("pieceName: official per-tier name with fallbacks", () => {
  assert.equal(Bz.pieceName(catalog[0], 5), "Bolsa del experto")
  assert.equal(Bz.pieceName(catalog[3], 6), "Vieja")
  assert.equal(Bz.pieceName(catalog[0], 7), "Bolsa")
  assert.equal(Bz.pieceName(null, 4, "BAG"), "BAG")
})

test("TOME_TIERS: T1-T8 with the official Spanish names", () => {
  assert.deepEqual(plain(Bz.TOME_TIERS.map((t) => t.tier)), [1, 2, 3, 4, 5, 6, 7, 8])
  assert.equal(Bz.TOME_TIERS[0].name, "Tomo de conocimiento del principiante")
  assert.equal(Bz.TOME_TIERS[6].name, "Tomo de conocimiento del gran maestro")
  assert.equal(Bz.TOME_TIERS[7].label, "anciano")
})

test("logLoot: tomes are optional, cleaned, and allowed with value 0", () => {
  let bz = ok(Bz.logLoot(empty(), { value: 0, tomes: { 3: 2, 6: 1, 5: 0 }, now: 1, id: "t1" }))
  assert.deepEqual(plain(bz.events[0]), { id: "t1", type: "loot", at: 1, value: 0, note: "", tomes: { 3: 2, 6: 1 } })
  bz = ok(Bz.logLoot(bz, { value: 10, tomes: { 9: 4, 2: -1, 4: 1.5, 7: "x" }, now: 2, id: "t2" }))
  assert.equal("tomes" in plain(bz.events[1]), false)
  bz = ok(Bz.logLoot(bz, { value: 10, tomes: { 1: 999999, 2: 1000000 }, now: 3, id: "t3" }))
  assert.deepEqual(plain(bz.events[2]).tomes, { 1: 999999 })
})

test("sanitizeBlackzone: keeps tomes, cleans them, leaves old loot unchanged", () => {
  const clean = plain(Bz.sanitizeBlackzone({ events: [
    { id: "a", type: "loot", at: 1, value: 5, note: "", tomes: { 2: 3, 4: 0, 11: 1, 5: -2 } },
    { id: "b", type: "loot", at: 1, value: 5, note: "", tomes: "x" },
    { id: "c", type: "loot", at: 1, value: 5, note: "" }
  ] }))
  assert.deepEqual(clean.events[0].tomes, { 2: 3 })
  assert.equal("tomes" in clean.events[1], false)
  assert.deepEqual(clean.events[2], { id: "c", type: "loot", at: 1, value: 5, note: "" })
})

test("totals: tomes per tier and in total, never part of profit", () => {
  let bz = ok(Bz.logLoot(empty(), { value: 100, tomes: { 3: 2, 6: 1 }, now: 1, id: "l1" }))
  bz = ok(Bz.logLoot(bz, { value: 0, tomes: { 3: 1 }, now: 2, id: "l2" }))
  bz = ok(Bz.logLoot(bz, { value: 50, now: 3, id: "l3" }))
  const t = plain(Bz.totals(bz))
  assert.deepEqual(t.tomes, { 3: 3, 6: 1 })
  assert.equal(t.tomeCount, 4)
  assert.equal(t.profit, 150)
  assert.deepEqual(plain(Bz.totals(empty())).tomes, {})
  assert.equal(Bz.totals(empty()).tomeCount, 0)
})
