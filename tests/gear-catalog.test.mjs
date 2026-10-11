import { test } from "node:test"
import assert from "node:assert/strict"
import { buildCatalog, slotOf, baseOf, tierOf, stripTierAdjective, renderCatalogModule } from "../scripts/gear-catalog.mjs"

const item = (UniqueName, es, en) => ({
  UniqueName,
  LocalizedNames: { ...(es ? { "ES-ES": es } : {}), ...(en ? { "EN-US": en } : {}) }
})

test("slotOf: maps UniqueName prefixes to slots", () => {
  assert.equal(slotOf("T6_HEAD_PLATE_SET1@2"), "head")
  assert.equal(slotOf("T4_ARMOR_LEATHER_SET2"), "armor")
  assert.equal(slotOf("T4_SHOES_CLOTH_SET3"), "shoes")
  assert.equal(slotOf("T4_MAIN_SWORD"), "mainhand")
  assert.equal(slotOf("T4_2H_BOW"), "mainhand")
  assert.equal(slotOf("T4_OFF_SHIELD"), "offhand")
  assert.equal(slotOf("T4_CAPE"), "cape")
  assert.equal(slotOf("T6_CAPEITEM_FW_LYMHURST"), "cape")
  assert.equal(slotOf("T4_BAG"), "bag")
  assert.equal(slotOf("T6_BAG_INSIGHT"), "bag")
  assert.equal(slotOf("T5_MOUNT_HORSE"), "mount")
  assert.equal(slotOf("T4_POTION_HEAL@1"), "potion")
  assert.equal(slotOf("T6_MEAL_SOUP"), "food")
})

test("slotOf: rejects non-equippable, skins, unique and event items", () => {
  for (const id of [
    "T4_MOUNTUPGRADE_HORSE", "T6_MOUNT_ARMORED_HORSE_SKIN_01", "UNIQUE_MOUNT_RAM_XMAS",
    "T6_CAPEITEM_FW_LYMHURST_BP", "T4_ARTEFACT_HEAD_PLATE_SET1", "T4_WOOD", "T4_JOURNAL_WARRIOR_EMPTY", "T8_MEAL_SPECIAL_FOOD_DRAKE_EGG",
    "SKIN_HORSE_FOUNDER_ASIA_GOLD", "T6_CAPE_PLATE_UNDEAD", "T6_CAPE_ARENA_BANNER", "T8_HEAD_CLOTH_PROTOTYPE"
  ]) assert.equal(slotOf(id), null, id)
})

test("baseOf / tierOf: strip tier prefix and enchant suffix", () => {
  assert.equal(baseOf("T6_HEAD_PLATE_SET1@2"), "HEAD_PLATE_SET1")
  assert.equal(baseOf("T4_2H_BOW"), "2H_BOW")
  assert.equal(tierOf("T6_HEAD_PLATE_SET1@2"), 6)
  assert.equal(tierOf("UNIQUE_X"), null)
})

test("stripTierAdjective: removes the adjective of that tier only", () => {
  assert.equal(stripTierAdjective("Casco de soldado del maestro", 6), "Casco de soldado")
  assert.equal(stripTierAdjective("Arco del gran maestro", 7), "Arco")
  assert.equal(stripTierAdjective("Espada ancha del principiante", 1), "Espada ancha")
  assert.equal(stripTierAdjective("Capa del anciano", 8), "Capa")
  assert.equal(stripTierAdjective("Capa de Contrabandista del Maestro", 6), "Capa de Contrabandista")
  assert.equal(stripTierAdjective("Caballo de montar del obrero", 3), "Caballo de montar")
  assert.equal(stripTierAdjective("Alce", 6), "Alce")
  assert.equal(stripTierAdjective("Arco del maestro", 5), "Arco del maestro")
})

test("buildCatalog: groups tiers per base, dedupes enchants, sorts", () => {
  const catalog = buildCatalog([
    item("T4_HEAD_PLATE_SET1", "Casco de soldado del iniciado"),
    item("T4_HEAD_PLATE_SET1@1", "Casco de soldado del iniciado"),
    item("T4_HEAD_PLATE_SET1@2", "Casco de soldado del iniciado"),
    item("T6_HEAD_PLATE_SET1", "Casco de soldado del maestro"),
    item("T5_HEAD_PLATE_SET1@3", "Casco de soldado del experto"),
    item("T4_2H_BOW", "Arco del iniciado"),
    item("T4_WOOD", "Madera"),
    item("T4_MOUNTUPGRADE_HORSE", "Brida")
  ])
  assert.deepEqual(catalog, [
    { base: "2H_BOW", slot: "mainhand", nameEs: "Arco", tiers: [4] },
    { base: "HEAD_PLATE_SET1", slot: "head", nameEs: "Casco de soldado", tiers: [4, 5, 6] }
  ])
})

test("buildCatalog: consumables keep the official name of every tier", () => {
  const catalog = buildCatalog([
    item("T2_POTION_HEAL", "Poción de curación menor"),
    item("T4_POTION_HEAL@1", "Poción de curación"),
    item("T6_POTION_HEAL", "Poción de curación mayor"),
    item("T3_MEAL_SOUP", "Sopa de trigo"),
    item("T5_MEAL_SOUP", "Sopa de col"),
    item("T4_MEAL_ROAST", "Pollo asado"),
    item("T6_MEAL_ROAST", "Cerdo asado")
  ])
  assert.deepEqual(catalog, [
    { base: "MEAL_ROAST", slot: "food", nameEs: "Pollo asado", tiers: [4, 6], names: { 4: "Pollo asado", 6: "Cerdo asado" } },
    { base: "MEAL_SOUP", slot: "food", nameEs: "Sopa de trigo", tiers: [3, 5], names: { 3: "Sopa de trigo", 5: "Sopa de col" } },
    { base: "POTION_HEAL", slot: "potion", nameEs: "Poción de curación", tiers: [2, 4, 6],
      names: { 2: "Poción de curación menor", 4: "Poción de curación", 6: "Poción de curación mayor" } }
  ])
})

test("buildCatalog: falls back to EN-US, then skips unnamed items", () => {
  const catalog = buildCatalog([
    item("T4_MAIN_SWORD", null, "Broadsword"),
    item("T4_OFF_SHIELD", null, null),
    { UniqueName: "T4_OFF_TORCH" }
  ])
  assert.deepEqual(catalog, [{ base: "MAIN_SWORD", slot: "mainhand", nameEs: "Broadsword", tiers: [4] }])
})

test("renderCatalogModule: pragma library module with one entry per line", () => {
  const text = renderCatalogModule([{ base: "2H_BOW", slot: "mainhand", nameEs: "Arco", tiers: [4, 5] }])
  assert.match(text, /^\/\/ .*generated/i)
  assert.match(text, /\.pragma library/)
  const body = text.replace(/^\.pragma library\s*$/m, "")
  const ctx = {}
  new Function("ctx", body.replace("var ITEMS", "ctx.ITEMS"))(ctx)
  assert.deepEqual(ctx.ITEMS, [{ base: "2H_BOW", slot: "mainhand", nameEs: "Arco", tiers: [4, 5] }])
})
