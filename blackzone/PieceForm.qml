import QtQuick
import "Blackzone.js" as Bz
import "GearCatalog.js" as Catalog

// State of the "Agregar pieza" form of the set editor (one form, shared by
// whichever set is being edited) plus the labels of gear pieces.
QtObject {
  id: root

  property string slot: "head"
  property string base: ""
  property int tier: 6
  property int enchant: 0
  property int quality: 1

  readonly property var catalogIndex: buildCatalogIndex()
  readonly property var entry: root.base !== "" ? (root.catalogIndex[root.base] || null) : null
  readonly property bool isConsumable: Bz.isConsumableSlot(root.slot)
  readonly property var baseOptions: Bz.pieceOptions(Catalog.ITEMS, root.slot)
  readonly property var tierOptions: (root.entry ? root.entry.tiers : []).map(function(t) {
    return { value: String(t), label: "T" + t }
  })
  readonly property var enchantOptions: [0, 1, 2, 3, 4].map(function(e) { return { value: String(e), label: "." + e } })
  readonly property var qualityOptions: [
    { value: "1", label: "Normal" }, { value: "2", label: "Bueno" }, { value: "3", label: "Notable" },
    { value: "4", label: "Sobresaliente" }, { value: "5", label: "Obra maestra" }
  ]

  // The form was reset: fields that hold their own text clear it.
  signal cleared()

  function buildCatalogIndex() {
    var index = {}
    for (var i = 0; i < Catalog.ITEMS.length; i++) index[Catalog.ITEMS[i].base] = Catalog.ITEMS[i]
    return index
  }

  function reset() {
    root.base = ""
    root.tier = 6
    root.enchant = 0
    root.quality = 1
    root.cleared()
  }

  function setSlot(value) {
    root.slot = value
    root.reset()
  }

  // Picking a search option sets both the base and its tier.
  function setOption(value) {
    var parsed = Bz.parsePieceOption(value)
    if (!parsed) return
    root.base = parsed.base
    root.tier = parsed.tier
  }

  // The game's own full name for the piece at that tier.
  function pieceName(base, tier) {
    return Bz.pieceName(root.catalogIndex[base] || null, tier, base)
  }

  function qualityName(q) {
    for (var i = 0; i < root.qualityOptions.length; i++)
      if (root.qualityOptions[i].value === String(q)) return root.qualityOptions[i].label
    return String(q)
  }

  function pieceLabel(piece) {
    var text = root.pieceName(piece.base, piece.tier) + " T" + piece.tier + "." + piece.enchant
    if (Bz.isConsumableSlot(piece.slot)) return piece.quantity > 1 ? text + " ×" + piece.quantity : text
    return text + " · " + root.qualityName(piece.quality)
  }
}
