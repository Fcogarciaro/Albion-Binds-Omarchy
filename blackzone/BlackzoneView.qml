import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Blackzone.js" as Bz
import "GearCatalog.js" as Catalog
import "../farm/Farm.js" as Farm
import "../farm/Prices.js" as Prices
import "../components"

// "Zona negra" tab: capture first. Summary, three actions (botín, gasto,
// muerte), one compose card at a time, the latest movements and, collapsed at
// the bottom, the gear sets.
// Data lives in owner.store (DataStore); every change is saved right away.
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
  readonly property var catalogIndex: buildCatalogIndex()

  // The open compose card: "" (none), "loot", "expense" or "death". Only one at a time.
  property string composer: ""
  // Brief confirmation after a save ("" = hidden); cleared by savedTimer.
  property string savedText: ""
  // "Ver todo" in the narrow panel.
  property bool historyAll: false
  // "Mis sets" is collapsed until asked for.
  property bool setsOpen: false

  property string errorText: ""
  // Delete control awaiting its second tap ("set:<id>", "piece:<n>", "ev:<id>").
  property string confirmKey: ""

  // Set editor: the set whose pieces are being edited ("" = none).
  property string editSetId: ""
  property string pieceSlot: "head"
  property string pieceBase: ""
  property int pieceTier: 6
  property int pieceEnchant: 0
  property int pieceQuality: 1
  readonly property var editSet: findSet(editSetId)
  readonly property var pieceEntry: pieceBase !== "" ? (catalogIndex[pieceBase] || null) : null
  readonly property bool pieceIsConsumable: Bz.isConsumableSlot(pieceSlot)
  readonly property var baseOptions: optionsForSlot(pieceSlot)

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

  // Fields and dropdowns of the set editor live inside the sets Repeater, so
  // their ids are not reachable from here: the open editor reports through
  // editorBusy, and values are passed in as arguments.
  property bool editorBusy: false
  signal pieceFormCleared()

  // Tome counters live inside a Repeater too: they push their text here
  // (tomeInput: { "<tier>": "text" }) and report focus through tomeBusy.
  property var tomeInput: ({})
  property bool tomeBusy: false
  signal tomeFormCleared()

  function setTomeText(tier, text) {
    var next = {}
    for (var k in tomeInput) next[k] = tomeInput[k]
    next[tier] = text
    tomeInput = next
  }

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

  // Counts typed in the tome fields, or null when one is not a whole number.
  function parseTomeInput() {
    var out = {}
    for (var k in tomeInput) {
      var text = String(tomeInput[k]).trim()
      if (text === "") continue
      var n = Farm.parseInteger(text)
      if (n === null) return null
      if (n > 0) out[k] = n
    }
    return out
  }

  function hasTomes(tomes) {
    for (var k in tomes) return true
    return false
  }

  readonly property bool editing: newSetField.activeFocus || editorBusy
    || tomeBusy || deathValueField.activeFocus || lootValueField.activeFocus || lootNoteField.activeFocus
    || expenseValueField.activeFocus || expenseNoteField.activeFocus
    || cityDropdown.popupOpen || serverDropdown.popupOpen

  readonly property var enchantOptions: [0, 1, 2, 3, 4].map(function(e) { return { value: String(e), label: "." + e } })
  readonly property var qualityOptions: [
    { value: "1", label: "Normal" }, { value: "2", label: "Bueno" }, { value: "3", label: "Notable" },
    { value: "4", label: "Sobresaliente" }, { value: "5", label: "Obra maestra" }
  ]

  spacing: Style.space(14)

  // ---------- Helpers ----------

  function buildCatalogIndex() {
    var index = {}
    for (var i = 0; i < Catalog.ITEMS.length; i++) index[Catalog.ITEMS[i].base] = Catalog.ITEMS[i]
    return index
  }

  function optionsForSlot(slot) {
    return Bz.pieceOptions(Catalog.ITEMS, slot)
  }

  function findSet(id) {
    var sets = blackzone.sets
    for (var i = 0; i < sets.length; i++) if (sets[i].id === id) return sets[i]
    return null
  }

  // The game's own full name for the piece at that tier.
  function pieceName(base, tier) {
    return Bz.pieceName(catalogIndex[base] || null, tier, base)
  }

  function qualityName(q) {
    for (var i = 0; i < qualityOptions.length; i++) if (qualityOptions[i].value === String(q)) return qualityOptions[i].label
    return String(q)
  }

  function pieceLabel(piece) {
    var text = pieceName(piece.base, piece.tier) + " T" + piece.tier + "." + piece.enchant
    if (Bz.isConsumableSlot(piece.slot)) return piece.quantity > 1 ? text + " ×" + piece.quantity : text
    return text + " · " + qualityName(piece.quality)
  }

  function tierOptions() {
    var tiers = pieceEntry ? pieceEntry.tiers : []
    return tiers.map(function(t) { return { value: String(t), label: "T" + t } })
  }

  function shortDate(ms) { return Qt.formatDate(new Date(ms), "dd/MM") }
  function newId(prefix) { return prefix + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36) }
  function signed(n) { return (n > 0 ? "+" : "") + Farm.formatSilver(n) }

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

  // Remembers form choices (city, death set, expense note) in the data file's ui section.
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
    if (!deathValueTouched) deathValueField.text = ""
    if (composer === "death") fetchDeathPrices()
  }
  onCityChanged: resetDeathPrices()
  onServerChanged: resetDeathPrices()

  // Focus goes to a section's first field once it is visible.
  function focusSoon(openCheck, focusIt) {
    Qt.callLater(function() { if (openCheck()) focusIt() })
  }

  function deleteLabel(key, idle) { return confirmKey === key ? "¿Seguro?" : idle }

  // Two-tap delete: the first tap arms the control, the second one runs it.
  function askDelete(key, action) {
    if (confirmKey !== key) {
      confirmKey = key
      confirmTimer.restart()
      return
    }
    confirmKey = ""
    confirmTimer.stop()
    action()
  }

  // ---------- Sets ----------

  function toggleSets() {
    setsOpen = !setsOpen
    errorText = ""
    confirmKey = ""
  }

  function addSet() {
    var id = newId("s")
    if (commit(Bz.addSet(blackzone, newSetField.text, id))) {
      newSetField.text = ""
      openEditor(id)
    }
  }

  function openEditor(setId) {
    confirmKey = ""
    errorText = ""
    if (editSetId === setId) { editSetId = ""; return }
    editSetId = setId
    var set = findSet(setId)
    resetPieceForm()
  }

  function resetPieceForm() {
    pieceBase = ""
    pieceTier = 6
    pieceEnchant = 0
    pieceQuality = 1
    pieceFormCleared()
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

  function setPieceSlot(slot) {
    pieceSlot = slot
    resetPieceForm()
  }

  // Picking a search option sets both the base and its tier.
  function setPieceOption(value) {
    var parsed = Bz.parsePieceOption(value)
    if (!parsed) return
    pieceBase = parsed.base
    pieceTier = parsed.tier
  }

  function addPiece(quantityText) {
    if (pieceBase === "") { errorText = "Elige una pieza de la lista."; return }
    var quantity = 1
    if (pieceIsConsumable && quantityText.trim() !== "") {
      quantity = Farm.parseInteger(quantityText)
      if (quantity === null || quantity < 1) { errorText = "La cantidad debe ser un número entero mayor que 0."; return }
    }
    var ok = commit(Bz.addPiece(blackzone, editSetId, {
      slot: pieceSlot, base: pieceBase, tier: pieceTier, enchant: pieceEnchant,
      quality: pieceIsConsumable ? 1 : pieceQuality, quantity: quantity
    }, Catalog.ITEMS))
    if (ok) resetPieceForm()
  }

  function removePiece(index) {
    commit(Bz.removePiece(blackzone, editSetId, index))
  }

  // ---------- Compose cards ----------

  // Opens the card for `kind`; tapping the open one closes it. The first field gets the focus.
  function openComposer(kind) {
    if (composer === kind) { closeComposer(); return }
    errorText = ""
    confirmKey = ""
    composer = kind
    if (kind === "death") prepareDeath("")
    focusSoon(function() { return composer === kind }, function() { firstField(kind).forceActiveFocus() })
  }

  function firstField(kind) {
    return kind === "death" ? deathValueField : kind === "expense" ? expenseValueField : lootValueField
  }

  function closeComposer() {
    composer = ""
    errorText = ""
    if (catcher) catcher.forceActiveFocus()
  }

  // A successful save closes the card and flashes "Guardado".
  function saved() {
    savedText = "Guardado"
    savedTimer.restart()
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
    deathValueField.text = ""
    deathValueTouched = false
    priceQueued = false
    if (store.document.ui.deathSetId !== id) rememberUi({ deathSetId: id })
  }

  // "Morí con este set": opens the death card on that set (prices are fetched on selection).
  function diedWithSet(setId) {
    errorText = ""
    confirmKey = ""
    composer = "death"
    setsOpen = false
    prepareDeath(setId)
    focusSoon(function() { return composer === "death" }, function() { deathValueField.forceActiveFocus() })
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
    if (!deathValueTouched) deathValueField.text = String(pricedValue())
    var missing = missingPrices()
    priceText = "Precios de " + priceProc.city + " (pueden estar desactualizados)."
      + (missing > 0 ? " " + missing + " pieza(s) sin precio: revisa el total." : "")
  }

  function saveDeath() {
    var typed = deathValueField.text.trim() === "" ? null : Farm.parseSilver(deathValueField.text)
    if (deathValueField.text.trim() !== "" && typed === null) { errorText = "Valor no válido. Usa un número entero o 450k, 1.2m."; return }
    if (typed === null && pricedValue() === 0) { errorText = "Consulta los precios o escribe el valor perdido."; return }
    var input = { setId: deathSetId, now: Date.now(), id: newId("d"), prices: deathPrices }
    if (typed !== null) input.value = typed
    if (commit(Bz.logDeath(blackzone, input))) {
      deathPrices = ({})
      priceText = ""
      deathValueField.text = ""
      deathValueTouched = false
      saved()
    }
  }

  // ---------- Loot ----------

  function saveLoot() {
    var tomes = parseTomeInput()
    if (tomes === null) { errorText = "Los tomos deben ser números enteros."; return }
    var value = lootValueField.text.trim() === "" && hasTomes(tomes) ? 0 : Farm.parseSilver(lootValueField.text)
    if (value === null) { errorText = "Valor no válido. Usa un número entero o 450k, 1.2m."; return }
    if (commit(Bz.logLoot(blackzone, { value: value, tomes: tomes, note: lootNoteField.text, now: Date.now(), id: newId("l") }))) {
      tomeInput = ({})
      tomeFormCleared()
      lootValueField.text = ""
      lootNoteField.text = ""
      saved()
    }
  }

  // ---------- Expenses ----------

  // Opening the expense card prefills the last note (openComposer); the value is always typed.
  // One tap re-logs the last expense: same value and note, new id and time.
  function repeatExpense() {
    var last = lastExpense
    if (!last) return
    if (commit(Bz.logExpense(blackzone, { value: last.value, note: last.note, now: Date.now(), id: newId("x") })))
      saved()
  }

  function saveExpense() {
    var value = Farm.parseSilver(expenseValueField.text)
    if (value === null || value <= 0) { errorText = "El gasto debe ser un número mayor que 0 (ej. 12k, 1.5m)."; return }
    if (commit(Bz.logExpense(blackzone, { value: value, note: expenseNoteField.text, now: Date.now(), id: newId("x") }))) {
      expenseValueField.text = ""
      expenseNoteField.text = ""
      saved()
    }
  }

  function removeEvent(id) {
    commit(Bz.removeEvent(blackzone, id))
  }

  // An armed delete control disarms itself if the second tap never comes.
  Timer {
    id: confirmTimer
    interval: 4000
    onTriggered: view.confirmKey = ""
  }

  Timer {
    id: savedTimer
    interval: 2000
    onTriggered: view.savedText = ""
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
  Row {
    id: lanes
    visible: view.wide
    width: parent.width
    spacing: Style.space(16)

    Column {
      id: leftLane
      width: (lanes.width - lanes.spacing) / 2
      spacing: view.spacing
    }

    Column {
      id: rightLane
      width: (lanes.width - lanes.spacing) / 2
      spacing: view.spacing
    }
  }

  // ---------- Summary ----------
  Column {
    parent: view.wide ? rightLane : view
    width: parent.width
    spacing: Style.space(8)

    Item {
      width: parent.width
      implicitHeight: Math.max(balanceText.implicitHeight, savedLabel.implicitHeight)

      Text {
        id: balanceText
        anchors.left: parent.left
        anchors.right: savedLabel.visible ? savedLabel.left : parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: (view.sums.profit > 0 ? "Ganancia: " : "Balance: ") + view.signed(view.sums.profit) + " plata"
        color: view.sums.profit < 0 ? Color.urgent : owner.bar.foreground
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        id: savedLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: view.savedText !== ""
        textFormat: Text.PlainText
        text: "✓ " + view.savedText
        color: Color.accent
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Stat {
        width: (parent.width - 2 * parent.spacing) / 3
        label: "Ganado (" + view.sums.loots + ")"
        value: Farm.formatSilver(view.sums.loot)
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Stat {
        width: (parent.width - 2 * parent.spacing) / 3
        label: "Perdido (" + view.sums.deaths + ")"
        value: Farm.formatSilver(view.sums.lost)
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Stat {
        width: (parent.width - 2 * parent.spacing) / 3
        label: "Gastado (" + view.sums.expenses + ")"
        value: Farm.formatSilver(view.sums.spent)
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }
    }

    Text {
      readonly property string detail: (view.sums.lootPerDeath !== null ? "Botín medio por muerte: " + Farm.formatSilver(view.sums.lootPerDeath) : "")
        + view.tomeSummary(view.sums.tomes)
      visible: detail !== ""
      width: parent.width
      textFormat: Text.PlainText
      text: detail.replace(/^\n/, "")
      color: owner.bar.foreground
      opacity: 0.7
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  // ---------- Actions ----------
  Column {
    parent: view.wide ? leftLane : view
    width: parent.width
    spacing: Style.space(8)

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        width: (parent.width - 2 * parent.spacing) / 3
        text: "+ Botín"
        selected: view.composer === "loot"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.openComposer("loot")
      }

      Button {
        width: (parent.width - 2 * parent.spacing) / 3
        text: "+ Gasto"
        selected: view.composer === "expense"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.openComposer("expense")
      }

      Button {
        width: (parent.width - 2 * parent.spacing) / 3
        text: "✝ Muerte"
        selected: view.composer === "death"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.openComposer("death")
      }
    }

    Button {
      visible: view.lastExpense !== null
      width: parent.width
      text: view.lastExpense ? "↻ Repetir: " + view.lastExpense.note + " −" + Farm.formatShort(view.lastExpense.value) : ""
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      fontSize: Style.font.caption
      onClicked: view.repeatExpense()
    }
  }

  // ---------- Compose card (one at a time) ----------
  Column {
    parent: view.wide ? leftLane : view
    visible: view.composer !== "" || (view.errorText !== "" && !view.setsOpen) || view.store.error !== ""
    width: parent.width
    spacing: Style.space(8)

    ComposeCard {
      visible: view.composer === "loot"
      width: parent.width
      title: "Botín"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      onCloseRequested: view.closeComposer()

      TextField {
        id: lootValueField
        width: parent.width
        placeholderText: "Valor del botín (ej. 1.2m)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.saveLoot()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "Tomos de conocimiento (cantidad por nivel, sin valor en plata)"
        color: owner.bar.foreground
        opacity: 0.7
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Flow {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: Bz.TOME_TIERS

          TextField {
            id: tomeField
            required property var modelData
            width: (parent.width - 3 * Style.space(6)) / 4
            placeholderText: "T" + modelData.tier
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.body
            foreground: owner.bar.foreground
            onTextChanged: view.setTomeText(modelData.tier, text)
            onAccepted: view.saveLoot()
            onActiveFocusChanged: view.tomeBusy = activeFocus
            Keys.onEscapePressed: view.catcher.forceActiveFocus()

            Connections {
              target: view
              function onTomeFormCleared() { tomeField.text = "" }
            }
          }
        }
      }

      TextField {
        id: lootNoteField
        width: parent.width
        placeholderText: "Nota (opcional)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.saveLoot()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Button {
        text: "Guardar botín"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.saveLoot()
      }
    }

    ComposeCard {
      visible: view.composer === "expense"
      width: parent.width
      title: "Gasto"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      onCloseRequested: view.closeComposer()

      TextField {
        id: expenseValueField
        width: parent.width
        placeholderText: "Gasto (ej. 12k)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.saveExpense()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      TextField {
        id: expenseNoteField
        width: parent.width
        placeholderText: "Portal SAFE"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.saveExpense()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Button {
        text: "Guardar gasto"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.saveExpense()
      }
    }

    ComposeCard {
      visible: view.composer === "death"
      width: parent.width
      title: "Muerte"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      onCloseRequested: view.closeComposer()

      Text {
        visible: view.blackzone.sets.length === 0
        width: parent.width
        text: "Crea un set con piezas primero."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Button {
        visible: view.blackzone.sets.length === 0
        text: "Crear un set"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: { view.closeComposer(); view.setsOpen = true }
      }

      Flow {
        visible: view.blackzone.sets.length > 0
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: view.blackzone.sets

          Button {
            id: setChip
            required property var modelData
            text: modelData.name
            selected: view.deathSetId === modelData.id
            foreground: owner.bar.foreground
            fontFamily: owner.bar.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            onClicked: view.pickDeathSet(setChip.modelData.id)
          }
        }
      }

      Row {
        visible: view.blackzone.sets.length > 0
        width: parent.width
        spacing: Style.space(6)

        Dropdown {
          id: cityDropdown
          width: parent.width - priceButton.width - parent.spacing
          label: "Ciudad"
          value: view.city
          options: Prices.CITIES
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          onChanged: function(v) { view.setCity(v) }
        }

        Button {
          id: priceButton
          text: "Actualizar precios"
          anchors.verticalCenter: cityDropdown.verticalCenter
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.fetchDeathPrices()
        }
      }

      Dropdown {
        id: serverDropdown
        visible: view.blackzone.sets.length > 0
        width: parent.width
        label: "Servidor"
        value: view.server
        options: Prices.SERVER_OPTIONS
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        onChanged: function(v) { view.setServer(v) }
      }

      Text {
        visible: view.priceText !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: view.priceText
        color: owner.bar.foreground
        opacity: 0.7
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: view.deathSet ? view.deathSet.pieces : []

        Item {
          id: deathPiece
          required property var modelData
          readonly property var price: view.deathPrices[Bz.priceKey(modelData)]
          width: parent.width
          implicitHeight: Math.max(deathPieceText.implicitHeight, deathPiecePrice.implicitHeight)

          Text {
            id: deathPieceText
            anchors.left: parent.left
            anchors.right: deathPiecePrice.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: view.pieceLabel(deathPiece.modelData)
            color: owner.bar.foreground
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            id: deathPiecePrice
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: typeof deathPiece.price === "number" ? Farm.formatSilver(deathPiece.price * deathPiece.modelData.quantity) : "sin precio"
            color: owner.bar.foreground
            opacity: typeof deathPiece.price === "number" ? 1 : 0.6
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      Text {
        visible: view.blackzone.sets.length > 0
        width: parent.width
        text: "Total perdido (editable)"
        color: owner.bar.foreground
        opacity: 0.7
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: deathValueField
        visible: view.blackzone.sets.length > 0
        width: parent.width
        placeholderText: "Valor perdido (ej. 450k)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onTextEdited: view.deathValueTouched = true
        onAccepted: view.saveDeath()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Button {
        visible: view.blackzone.sets.length > 0
        text: "Guardar muerte"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.saveDeath()
      }
    }

    Text {
      visible: view.errorText !== "" || view.store.error !== ""
      width: parent.width
      textFormat: Text.PlainText
      text: view.errorText !== "" ? view.errorText : view.store.error
      color: Color.urgent
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  // ---------- Latest movements ----------
  Column {
    parent: view.wide ? rightLane : view
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { visible: !view.wide; foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(historyHeader.implicitHeight, historyToggle.implicitHeight)

      PanelSectionHeader {
        id: historyHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: view.wide ? "HISTORIAL" : "ÚLTIMOS MOVIMIENTOS"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: historyToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !view.wide && view.eventCount > 3
        text: view.historyAll ? "Ver menos ‹" : "Ver todo ›"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        onClicked: view.historyAll = !view.historyAll
      }
    }

    Text {
      visible: view.eventCount === 0
      width: parent.width
      text: "Aún no hay movimientos. Registra un botín, un gasto o una muerte arriba."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: view.history

      Item {
        id: historyRow
        required property var modelData
        readonly property bool isDeath: modelData.type === "death"
        readonly property bool isExpense: modelData.type === "expense"
        width: parent.width
        implicitHeight: Math.max(historyLabel.implicitHeight, historyValue.implicitHeight, historyDelete.implicitHeight)

        Text {
          id: historyLabel
          anchors.left: parent.left
          anchors.right: historyValue.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: view.shortDate(historyRow.modelData.at) + " · "
            + (historyRow.isDeath
              ? "Muerte · " + historyRow.modelData.setName + (historyRow.modelData.partial ? " (parcial)" : "")
              : historyRow.isExpense
                ? "Gasto · " + historyRow.modelData.note
                : "Botín" + (historyRow.modelData.note !== "" ? " · " + historyRow.modelData.note : "")
                + (historyRow.modelData.tomes ? " · Tomos: " + view.tomesText(historyRow.modelData.tomes) : ""))
          color: owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          id: historyValue
          anchors.right: historyDelete.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: view.signed(historyRow.isDeath || historyRow.isExpense ? -historyRow.modelData.value : historyRow.modelData.value)
          color: historyRow.isDeath || historyRow.isExpense ? Color.urgent : owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Button {
          id: historyDelete
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: view.deleteLabel("ev:" + historyRow.modelData.id, "Eliminar")
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.caption
          bordered: true
          onClicked: view.askDelete("ev:" + historyRow.modelData.id, function() { view.removeEvent(historyRow.modelData.id) })
        }
      }
    }

    Text {
      visible: view.historyExpanded && view.eventCount > view.historyLimit
      width: parent.width
      text: "Mostrando los últimos " + view.historyLimit + " de " + view.eventCount + "."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---------- My sets (collapsed) ----------
  Column {
    parent: view.wide ? leftLane : view
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Button {
      width: parent.width
      leftAlign: true
      text: "Mis sets (" + view.blackzone.sets.length + ") " + (view.setsOpen ? "⌄" : "›")
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: view.toggleSets()
    }

    Column {
      visible: view.setsOpen
      width: parent.width
      spacing: Style.space(8)

      Text {
        visible: view.blackzone.sets.length === 0
        width: parent.width
        text: "Sin sets. Crea uno abajo y agrégale piezas."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: view.blackzone.sets

        Column {
          id: setRow
          required property var modelData
          readonly property var total: view.sums.bySet[modelData.id]
          readonly property bool isEditing: view.editSetId === modelData.id
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(setLabels.implicitHeight, setEdit.implicitHeight)

            Column {
              id: setLabels
              anchors.left: parent.left
              anchors.right: setEdit.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: setRow.modelData.name
                color: owner.bar.foreground
                font.family: owner.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: setRow.modelData.pieces.length + " pieza(s)"
                  + (setRow.total ? " · " + setRow.total.deaths + " muerte(s), -" + Farm.formatSilver(setRow.total.lost) : "")
                color: owner.bar.foreground
                opacity: 0.7
                font.family: owner.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }

              Button {
                visible: setRow.modelData.pieces.length > 0
                text: "Morí con este set"
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                fontSize: Style.font.caption
                bordered: true
                onClicked: view.diedWithSet(setRow.modelData.id)
              }
            }

            Button {
              id: setEdit
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: setRow.isEditing ? "Cerrar" : "Editar"
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: view.openEditor(setRow.modelData.id)
            }
          }

          Column {
            visible: setRow.isEditing
            width: parent.width
            spacing: Style.space(6)
            onVisibleChanged: if (visible) renameField.text = setRow.modelData.name

            Binding {
              target: view
              property: "editorBusy"
              when: setRow.isEditing
              value: renameField.activeFocus || quantityField.activeFocus
                || pieceSlotDropdown.popupOpen || pieceBaseDropdown.popupOpen || pieceTierDropdown.popupOpen
                || pieceEnchantDropdown.popupOpen || pieceQualityDropdown.popupOpen
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: renameField
                width: parent.width - renameButton.width - parent.spacing
                placeholderText: "Nombre del set"
                font.family: owner.bar.fontFamily
                font.pixelSize: Style.font.body
                foreground: owner.bar.foreground
                onAccepted: view.renameSet(renameField.text)
                Keys.onEscapePressed: view.catcher.forceActiveFocus()
              }

              Button {
                id: renameButton
                text: "Renombrar"
                anchors.verticalCenter: renameField.verticalCenter
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                onClicked: view.renameSet(renameField.text)
              }
            }

            Repeater {
              model: setRow.modelData.pieces

              Item {
                id: pieceRow
                required property var modelData
                required property int index
                width: parent.width
                implicitHeight: Math.max(pieceText.implicitHeight, pieceDelete.implicitHeight)

                Text {
                  id: pieceText
                  anchors.left: parent.left
                  anchors.right: pieceDelete.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: view.pieceLabel(pieceRow.modelData)
                  color: owner.bar.foreground
                  font.family: owner.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Button {
                  id: pieceDelete
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Quitar"
                  foreground: owner.bar.foreground
                  fontFamily: owner.bar.fontFamily
                  fontSize: Style.font.caption
                  bordered: true
                  onClicked: view.removePiece(pieceRow.index)
                }
              }
            }

            Text {
              text: "Agregar pieza"
              color: owner.bar.foreground
              opacity: 0.7
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Dropdown {
              id: pieceSlotDropdown
              width: parent.width
              label: "Ranura"
              value: view.pieceSlot
              options: Bz.SLOTS
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              onChanged: function(v) { view.setPieceSlot(v) }
            }

            SearchableDropdown {
              id: pieceBaseDropdown
              width: parent.width
              label: "Pieza"
              value: view.pieceBase !== "" ? view.pieceBase + ":" + view.pieceTier : ""
              options: view.baseOptions
              placeholderText: "Buscar…"
              emptyText: "Sin resultados"
              triggerLabel: "Elige una pieza"
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              onChanged: function(v) { view.setPieceOption(v) }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Dropdown {
                id: pieceTierDropdown
                width: (parent.width - parent.spacing * (view.pieceIsConsumable ? 1 : 2)) / (view.pieceIsConsumable ? 2 : 3)
                label: "Nivel"
                value: String(view.pieceTier)
                options: view.tierOptions()
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                onChanged: function(v) { view.pieceTier = Number(v) }
              }

              Dropdown {
                id: pieceEnchantDropdown
                width: pieceTierDropdown.width
                label: "Encantamiento"
                value: String(view.pieceEnchant)
                options: view.enchantOptions
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                onChanged: function(v) { view.pieceEnchant = Number(v) }
              }

              Dropdown {
                id: pieceQualityDropdown
                visible: !view.pieceIsConsumable
                width: pieceTierDropdown.width
                label: "Calidad"
                value: String(view.pieceQuality)
                options: view.qualityOptions
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                onChanged: function(v) { view.pieceQuality = Number(v) }
              }
            }

            TextField {
              id: quantityField
              visible: view.pieceIsConsumable
              width: parent.width
              placeholderText: "Cantidad (1 si lo dejas vacío)"
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.body
              foreground: owner.bar.foreground
              onAccepted: view.addPiece(quantityField.text)
              Keys.onEscapePressed: view.catcher.forceActiveFocus()

              Connections {
                target: view
                function onPieceFormCleared() { quantityField.text = "" }
              }
            }

            Button {
              text: "Agregar pieza"
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: view.addPiece(quantityField.text)
            }

            Button {
              text: view.deleteLabel("set:" + setRow.modelData.id, "Eliminar set")
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: view.askDelete("set:" + setRow.modelData.id, function() { view.removeSet(setRow.modelData.id) })
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        TextField {
          id: newSetField
          width: parent.width - addSetButton.width - parent.spacing
          placeholderText: "Nombre del set nuevo"
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: owner.bar.foreground
          onAccepted: view.addSet()
          Keys.onEscapePressed: view.catcher.forceActiveFocus()
        }

        Button {
          id: addSetButton
          text: "Crear"
          anchors.verticalCenter: newSetField.verticalCenter
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.addSet()
        }
      }

      Text {
        width: parent.width
        text: "Borrar un set no borra las muertes ya registradas."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Text {
        visible: view.errorText !== "" && view.composer === ""
        width: parent.width
        textFormat: Text.PlainText
        text: view.errorText
        color: Color.urgent
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
