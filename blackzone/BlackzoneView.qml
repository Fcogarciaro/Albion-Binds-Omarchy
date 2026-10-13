import QtQuick
import Quickshell.Io
import qs.Commons
import "Blackzone.js" as Bz
import "GearCatalog.js" as Catalog
import "../farm/Farm.js" as Farm
import "../farm/Prices.js" as Prices
import "../shared/ViewHelpers.js" as Helpers
import "../components"

// "Zona negra" tab: capture first. Summary, three actions (botín, gasto,
// muerte), one compose card at a time, the latest movements and, collapsed at
// the bottom, the gear sets.
// Data lives in owner.store (DataStore); every change is saved right away.
// This file holds the state and logic; the pieces live in BzSummary,
// BzActions, LootCard, ExpenseCard, DeathCard, SetsSection (with SetCard and
// PieceForm) and the shared HistoryList.
Column {
  id: view

  required property var owner
  // Item that takes focus back when a text field is dismissed with Esc.
  property Item catcher: null
  // Two-column layout, used by the large window. The bar panel keeps one column.
  property bool wide: false

  readonly property var store: owner.store
  readonly property var blackzone: store.document.blackzone
  readonly property var sums: Bz.totals(blackzone)
  // Latest movements: 3 by default, more when expanded (always in the wide window).
  readonly property bool historyExpanded: wide || historyAll
  readonly property int historyLimit: historyExpanded ? (wide ? 50 : 12) : 3
  readonly property var history: Bz.recentEvents(blackzone, historyLimit)
  readonly property int eventCount: blackzone.events.length
  readonly property var historyRows: history.map(function(e) {
    var negative = e.type === "death" || e.type === "expense"
    var label
    if (e.type === "death") label = "Muerte · " + e.setName + (e.partial ? " (parcial)" : "")
    else if (e.type === "expense") label = "Gasto · " + e.note
    else label = "Botín" + (e.note !== "" ? " · " + e.note : "") + (e.tomes ? " · Tomos: " + tomesText(e.tomes) : "")
    return {
      id: e.id,
      label: Helpers.shortDate(e.at) + " · " + label,
      valueText: Farm.signed(negative ? -e.value : e.value),
      urgent: negative
    }
  })

  // Brief confirmation after a save ("" = hidden).
  readonly property string savedText: notice.text
  // The open compose card: "" (none), "loot", "expense" or "death". Only one at a time.
  property string composer: ""
  // "Ver todo" in the narrow panel.
  property bool historyAll: false
  // "Mis sets" is collapsed until asked for.
  property bool setsOpen: false

  property string errorText: ""

  // Set editor: the set whose pieces are being edited ("" = none).
  property string editSetId: ""

  // Death form.
  property string deathSetId: ""
  // Shared with the Cultivos tab; remembered in the data file (ui section).
  readonly property string city: store.document.ui.city
  readonly property string server: store.document.ui.server
  readonly property var lastExpense: Bz.lastExpense(blackzone)
  property var deathPrices: ({})
  property string priceText: ""
  // The total was typed by hand: a late price answer must not overwrite it.
  property bool deathValueTouched: false
  // A price request was asked for while another one was still running.
  property bool priceQueued: false
  readonly property var deathSet: findSet(deathSetId)
  // One row per piece of the death set: label and its market price.
  readonly property var deathRows: deathSet ? deathSet.pieces.map(function(p) {
    var price = deathPrices[Bz.priceKey(p)]
    var known = typeof price === "number"
    return {
      label: pieceForm.pieceLabel(p),
      known: known,
      priceText: known ? Farm.formatSilver(price * p.quantity) : "sin precio"
    }
  }) : []

  // Average loot per death and the tomes, under the summary stats.
  readonly property string summaryDetail: ((sums.lootPerDeath !== null ? "Botín medio por muerte: " + Farm.formatSilver(sums.lootPerDeath) : "")
    + tomeSummary(sums.tomes)).replace(/^\n/, "")

  readonly property bool editing: setsSection.editing || lootCard.editing || expenseCard.editing || deathCard.editing

  spacing: look.gapSection

  ViewStyle {
    id: look
    foreground: view.owner.bar.foreground
    fontFamily: view.owner.bar.fontFamily
    wide: view.wide
  }

  // Two-tap delete state, shared by every delete control of the tab.
  DeleteConfirm { id: deletes }

  // "Guardado" notice after a save.
  SavedNotice { id: notice }

  // State and labels of the set editor's "Agregar pieza" form.
  PieceForm { id: pieceForm }

  // One "\n<official name>: <count>" line per tier with tomes (none -> "").
  function tomeSummary(tomes) {
    var out = ""
    for (var i = 0; i < Bz.TOME_TIERS.length; i++) {
      var t = Bz.TOME_TIERS[i]
      if (tomes && tomes[t.tier] > 0) out += "\n" + t.name + ": " + tomes[t.tier]
    }
    return out
  }

  // "T3 x2, T6 x1" for a loot's tomes (empty when none).
  function tomesText(tomes) {
    var parts = []
    for (var i = 0; i < Bz.TOME_TIERS.length; i++) {
      var tier = Bz.TOME_TIERS[i].tier
      if (tomes && tomes[tier] > 0) parts.push("T" + tier + " x" + tomes[tier])
    }
    return parts.join(", ")
  }

  // ---------- Helpers ----------

  function findSet(id) {
    var sets = blackzone.sets
    for (var i = 0; i < sets.length; i++) if (sets[i].id === id) return sets[i]
    return null
  }

  // Applies an operation result: persists it, or shows its error.
  function commit(result) {
    if (!result.ok) { errorText = result.error; return false }
    errorText = ""
    var next = Object.assign({}, store.document)
    next.blackzone = result.blackzone
    store.document = next
    store.saveData()
    return true
  }

  // Remembers form choices (city, server, death set) in the data file's ui section.
  function rememberUi(patch) {
    var next = Object.assign({}, store.document)
    next.ui = Object.assign({}, store.document.ui, patch)
    store.document = next
    store.saveData()
  }

  function setCity(value) { rememberUi({ city: value }) }
  function setServer(value) { rememberUi({ server: value }) }

  // Prices (and the total they filled in) belong to one city and server: a
  // change drops them and, with the death card open, asks again.
  function resetDeathPrices() {
    deathPrices = ({})
    priceText = ""
    if (!deathValueTouched) deathCard.valueText = ""
    if (composer === "death") fetchDeathPrices()
  }
  onCityChanged: resetDeathPrices()
  onServerChanged: resetDeathPrices()

  // Focus goes to a section's first field once it is visible.
  function focusSoon(openCheck, focusIt) {
    Qt.callLater(function() { if (openCheck()) focusIt() })
  }

  // ---------- Sets ----------

  function toggleSets() {
    setsOpen = !setsOpen
    errorText = ""
    deletes.reset()
  }

  function addSet() {
    var id = Helpers.newId("s")
    if (commit(Bz.addSet(blackzone, setsSection.newName, id))) {
      setsSection.newName = ""
      openEditor(id)
    }
  }

  function openEditor(setId) {
    deletes.reset()
    errorText = ""
    if (editSetId === setId) { editSetId = ""; return }
    editSetId = setId
    pieceForm.reset()
  }

  function renameSet(name) {
    commit(Bz.renameSet(blackzone, editSetId, name))
  }

  function removeSet(setId) {
    if (commit(Bz.removeSet(blackzone, setId))) {
      if (editSetId === setId) editSetId = ""
      if (deathSetId === setId) { deathSetId = ""; deathPrices = ({}); priceText = "" }
    }
  }

  function addPiece(quantityText) {
    if (pieceForm.base === "") { errorText = "Elige una pieza de la lista."; return }
    var quantity = 1
    if (pieceForm.isConsumable && quantityText.trim() !== "") {
      quantity = Farm.parseInteger(quantityText)
      if (quantity === null || quantity < 1) { errorText = "La cantidad debe ser un número entero mayor que 0."; return }
    }
    var ok = commit(Bz.addPiece(blackzone, editSetId, {
      slot: pieceForm.slot, base: pieceForm.base, tier: pieceForm.tier, enchant: pieceForm.enchant,
      quality: pieceForm.isConsumable ? 1 : pieceForm.quality, quantity: quantity
    }, Catalog.ITEMS))
    if (ok) pieceForm.reset()
  }

  function removePiece(index) {
    commit(Bz.removePiece(blackzone, editSetId, index))
  }

  // ---------- Compose cards ----------

  // Opens the card for `kind`; tapping the open one closes it. The first field gets the focus.
  function openComposer(kind) {
    if (composer === kind) { closeComposer(); return }
    errorText = ""
    deletes.reset()
    composer = kind
    if (kind === "death") prepareDeath("")
    focusSoon(function() { return composer === kind }, function() { focusComposer(kind) })
  }

  function focusComposer(kind) {
    if (kind === "death") deathCard.focusFirst()
    else if (kind === "expense") expenseCard.focusFirst()
    else lootCard.focusFirst()
  }

  function closeComposer() {
    composer = ""
    errorText = ""
    if (catcher) catcher.forceActiveFocus()
  }

  // A successful save closes the card and flashes "Guardado".
  function saved() {
    notice.flash()
    closeComposer()
  }

  // ---------- Death ----------

  // Selects the wanted set (else the remembered one, else the first) and fetches its prices.
  function prepareDeath(wantedId) {
    var set = findSet(wantedId) || findSet(deathSetId) || findSet(store.document.ui.deathSetId)
    if (!set && blackzone.sets.length > 0) set = blackzone.sets[0]
    if (set) pickDeathSet(set.id)
  }

  // Opening the card on the set already selected keeps its prices and writes
  // nothing; prices are fetched only for a new set or when none are loaded.
  function pickDeathSet(id) {
    var changed = id !== deathSetId
    if (changed) setDeathSet(id)
    if (changed || Object.keys(deathPrices).length === 0) fetchDeathPrices()
  }

  function setDeathSet(id) {
    deathSetId = id
    deathPrices = ({})
    priceText = ""
    deathCard.valueText = ""
    deathValueTouched = false
    priceQueued = false
    if (store.document.ui.deathSetId !== id) rememberUi({ deathSetId: id })
  }

  // "Morí con este set": opens the death card on that set (prices are fetched on selection).
  function diedWithSet(setId) {
    errorText = ""
    deletes.reset()
    composer = "death"
    setsOpen = false
    prepareDeath(setId)
    focusSoon(function() { return composer === "death" }, function() { deathCard.focusFirst() })
  }

  function pricedValue() {
    var set = deathSet
    if (!set) return 0
    var total = 0
    for (var i = 0; i < set.pieces.length; i++) {
      var price = deathPrices[Bz.priceKey(set.pieces[i])]
      if (typeof price === "number") total += price * set.pieces[i].quantity
    }
    return total
  }

  function missingPrices() {
    var set = deathSet
    if (!set) return 0
    return set.pieces.filter(function(p) { return typeof deathPrices[Bz.priceKey(p)] !== "number" }).length
  }

  // One request for every piece of the set; failures only set a message.
  function fetchDeathPrices() {
    var set = deathSet
    if (!set || set.pieces.length === 0) return
    if (priceProc.running) { priceQueued = true; priceText = "Consultando el mercado…"; return }
    var items = Bz.setItems(set)
    var ids = []
    var qualities = []
    for (var i = 0; i < items.length; i++) {
      if (ids.indexOf(items[i].itemId) < 0) ids.push(items[i].itemId)
      if (qualities.indexOf(items[i].quality) < 0) qualities.push(items[i].quality)
    }
    priceProc.city = city
    priceProc.server = server
    priceProc.setId = set.id
    priceProc.keys = set.pieces.map(function(p) { return Bz.priceKey(p) })
    priceText = "Consultando el mercado…"
    priceProc.command = Prices.curlArgs(Prices.buildUrl(ids, city, server, qualities), 10)
    priceProc.running = true
  }

  function applyDeathPrices(text) {
    // The set, city or server changed while the request ran: drop the stale
    // answer (a queued request runs on exit).
    if (priceProc.setId !== deathSetId || priceProc.city !== city || priceProc.server !== server) {
      if (!priceQueued) priceText = ""
      return
    }
    priceQueued = false
    var checked = Prices.checkResponse(text, "No pude consultar el mercado. Escribe el valor a mano.")
    if (!checked.ok) { priceText = checked.error; return }
    var result = Prices.parseQualityPrices(checked.body, priceProc.city, priceProc.keys)
    if (!result.ok) { priceText = "No pude consultar el mercado. Escribe el valor a mano."; return }
    deathPrices = result.prices
    if (!deathValueTouched) deathCard.valueText = String(pricedValue())
    var missing = missingPrices()
    priceText = "Precios de " + priceProc.city + " (pueden estar desactualizados)."
      + (missing > 0 ? " " + missing + " pieza(s) sin precio: revisa el total." : "")
  }

  function saveDeath() {
    var typed = deathCard.valueText.trim() === "" ? null : Farm.parseSilver(deathCard.valueText)
    if (deathCard.valueText.trim() !== "" && typed === null) { errorText = "Valor no válido. Usa un número entero o 450k, 1.2m."; return }
    if (typed === null && pricedValue() === 0) { errorText = "Consulta los precios o escribe el valor perdido."; return }
    var input = { setId: deathSetId, now: Date.now(), id: Helpers.newId("d"), prices: deathPrices }
    if (typed !== null) input.value = typed
    if (commit(Bz.logDeath(blackzone, input))) {
      deathPrices = ({})
      priceText = ""
      deathCard.valueText = ""
      deathValueTouched = false
      saved()
    }
  }

  // ---------- Loot ----------

  function saveLoot() {
    var tomes = lootCard.parseTomes()
    if (tomes === null) { errorText = "Los tomos deben ser números enteros."; return }
    var hasTomes = Object.keys(tomes).length > 0
    var empty = lootCard.valueText.trim() === ""
    if (empty && !hasTomes) { errorText = "Escribe el valor o los tomos."; return }
    var value = empty ? 0 : Farm.parseSilver(lootCard.valueText)
    if (value === null) { errorText = "Valor no válido. Usa un número entero o 450k, 1.2m."; return }
    if (commit(Bz.logLoot(blackzone, { value: value, tomes: tomes, note: lootCard.noteText, now: Date.now(), id: Helpers.newId("l") }))) {
      lootCard.clear()
      saved()
    }
  }

  // ---------- Expenses ----------

  // One tap re-logs the last expense: same value and note, new id and time.
  function repeatExpense() {
    var last = lastExpense
    if (!last) return
    if (commit(Bz.logExpense(blackzone, { value: last.value, note: last.note, now: Date.now(), id: Helpers.newId("x") })))
      saved()
  }

  function saveExpense() {
    var value = Farm.parseSilver(expenseCard.valueText)
    if (value === null || value <= 0) { errorText = "El gasto debe ser un número mayor que 0 (ej. 12k, 1.5m)."; return }
    if (commit(Bz.logExpense(blackzone, { value: value, note: expenseCard.noteText, now: Date.now(), id: Helpers.newId("x") }))) {
      expenseCard.clear()
      saved()
    }
  }

  function removeEvent(id) {
    commit(Bz.removeEvent(blackzone, id))
  }

  Process {
    id: priceProc
    property string city: ""
    property string server: ""
    property string setId: ""
    property var keys: []
    // A request asked for while this one ran starts once it has exited.
    onRunningChanged: if (!running && view.priceQueued) {
      view.priceQueued = false
      view.fetchDeathPrices()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyDeathPrices(text)
    }
  }

  // Large window: two lanes side by side. Capture (actions, compose card, sets)
  // goes left, the summary and the history go right. Sections below move into
  // them when `wide`; otherwise they stay direct children of this Column, in
  // declaration order: summary, actions, compose card, history, sets.
  LaneLayout {
    id: lanes
    width: parent.width
    wide: view.wide
    laneSpacing: look.gapLane
    sectionSpacing: view.spacing
  }

  // ---------- Summary ----------
  BzSummary {
    parent: view.wide ? lanes.rightLane : view
    width: parent.width
    theme: look
    sums: view.sums
    savedText: view.savedText
    detail: view.summaryDetail
  }

  // ---------- Actions ----------
  BzActions {
    parent: view.wide ? lanes.leftLane : view
    width: parent.width
    theme: look
    composer: view.composer
    repeatText: view.lastExpense ? "↻ Repetir: " + view.lastExpense.note + " −" + Farm.formatShort(view.lastExpense.value) : ""
    onOpenRequested: function(kind) { view.openComposer(kind) }
    onRepeatRequested: view.repeatExpense()
  }

  // ---------- Compose card (one at a time) ----------
  Column {
    parent: view.wide ? lanes.leftLane : view
    visible: view.composer !== "" || (view.errorText !== "" && !view.setsOpen) || view.store.error !== ""
    width: parent.width
    spacing: look.gap

    LootCard {
      id: lootCard
      visible: view.composer === "loot"
      width: parent.width
      theme: look
      catcher: view.catcher
      onCloseRequested: view.closeComposer()
      onSaveRequested: view.saveLoot()
    }

    ExpenseCard {
      id: expenseCard
      visible: view.composer === "expense"
      width: parent.width
      theme: look
      catcher: view.catcher
      onCloseRequested: view.closeComposer()
      onSaveRequested: view.saveExpense()
    }

    DeathCard {
      id: deathCard
      visible: view.composer === "death"
      width: parent.width
      theme: look
      catcher: view.catcher
      sets: view.blackzone.sets
      selectedSetId: view.deathSetId
      city: view.city
      server: view.server
      priceText: view.priceText
      rows: view.deathRows
      onCloseRequested: view.closeComposer()
      onCreateSetRequested: { view.closeComposer(); view.setsOpen = true }
      onSetPicked: function(id) { view.pickDeathSet(id) }
      onCityPicked: function(v) { view.setCity(v) }
      onServerPicked: function(v) { view.setServer(v) }
      onRefreshRequested: view.fetchDeathPrices()
      onValueEdited: view.deathValueTouched = true
      onSaveRequested: view.saveDeath()
    }

    ViewText {
      visible: view.errorText !== "" || view.store.error !== ""
      width: parent.width
      theme: look
      size: "caption"
      text: view.errorText !== "" ? view.errorText : view.store.error
      color: Color.urgent
      wrapMode: Text.WordWrap
    }
  }

  // ---------- Latest movements ----------
  HistoryList {
    parent: view.wide ? lanes.rightLane : view
    width: parent.width
    theme: look
    confirm: deletes
    title: view.wide ? "HISTORIAL" : "ÚLTIMOS MOVIMIENTOS"
    emptyText: "Aún no hay movimientos. Registra un botín, un gasto o una muerte arriba."
    rows: view.historyRows
    keyPrefix: "ev:"
    wide: view.wide
    canExpand: view.eventCount > 3
    expanded: view.historyAll
    footerText: view.historyExpanded && view.eventCount > view.historyLimit
      ? "Mostrando los últimos " + view.historyLimit + " de " + view.eventCount + "." : ""
    onToggleRequested: view.historyAll = !view.historyAll
    onDeleteRequested: function(id) { view.removeEvent(id) }
  }

  // ---------- My sets (collapsed) ----------
  SetsSection {
    id: setsSection
    parent: view.wide ? lanes.leftLane : view
    width: parent.width
    theme: look
    confirm: deletes
    form: pieceForm
    catcher: view.catcher
    open: view.setsOpen
    sets: view.blackzone.sets
    totals: view.sums.bySet
    editSetId: view.editSetId
    errorText: view.errorText !== "" && view.composer === "" ? view.errorText : ""
    onToggled: view.toggleSets()
    onCreateRequested: view.addSet()
    onEditToggled: function(setId) { view.openEditor(setId) }
    onDiedRequested: function(setId) { view.diedWithSet(setId) }
    onRenameRequested: function(name) { view.renameSet(name) }
    onPieceRemoveRequested: function(index) { view.removePiece(index) }
    onPieceAddRequested: function(quantityText) { view.addPiece(quantityText) }
    onSetRemoveRequested: function(setId) { view.removeSet(setId) }
  }
}
