import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Blackzone.js" as Bz
import "GearCatalog.js" as Catalog
import "../farm/Farm.js" as Farm
import "../farm/Prices.js" as Prices

// "Zona negra" tab: gear sets, death and loot logging, profit summary.
// Data lives in owner.store (DataStore); every change is saved right away.
Column {
  id: view

  required property var owner
  // Item that takes focus back when a text field is dismissed with Esc.
  property Item catcher: null

  readonly property var store: owner.store
  readonly property var blackzone: store.document.blackzone
  readonly property var sums: Bz.totals(blackzone)
  readonly property var history: Bz.recentEvents(blackzone, 12)
  readonly property var catalogIndex: buildCatalogIndex()

  // Collapsible sections.
  property bool setsOpen: true
  property bool deathOpen: false
  property bool lootOpen: false
  property bool historyOpen: true

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
  property string city: "Lymhurst"
  property var deathPrices: ({})
  property string priceText: ""
  readonly property var deathSet: findSet(deathSetId)

  readonly property bool editing: newSetField.activeFocus || renameField.activeFocus || quantityField.activeFocus
    || deathValueField.activeFocus || lootValueField.activeFocus || lootNoteField.activeFocus
    || pieceSlotDropdown.popupOpen || pieceBaseDropdown.popupOpen || pieceTierDropdown.popupOpen
    || pieceEnchantDropdown.popupOpen || pieceQualityDropdown.popupOpen
    || deathSetDropdown.popupOpen || cityDropdown.popupOpen

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
    renameField.text = set ? set.name : ""
    resetPieceForm()
  }

  function resetPieceForm() {
    pieceBase = ""
    pieceTier = 6
    pieceEnchant = 0
    pieceQuality = 1
    quantityField.text = ""
  }

  function renameSet() {
    commit(Bz.renameSet(blackzone, editSetId, renameField.text))
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

  function addPiece() {
    if (pieceBase === "") { errorText = "Elige una pieza de la lista."; return }
    var quantity = 1
    if (pieceIsConsumable && quantityField.text.trim() !== "") {
      quantity = Farm.parseInteger(quantityField.text)
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

  // ---------- Death ----------

  function toggleDeath() {
    deathOpen = !deathOpen
    if (deathOpen && deathSetId === "" && blackzone.sets.length > 0) setDeathSet(blackzone.sets[0].id)
  }

  function setDeathSet(id) {
    deathSetId = id
    deathPrices = ({})
    priceText = ""
    deathValueField.text = ""
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
    if (!set || set.pieces.length === 0 || priceProc.running) return
    var items = Bz.setItems(set)
    var ids = []
    var qualities = []
    for (var i = 0; i < items.length; i++) {
      if (ids.indexOf(items[i].itemId) < 0) ids.push(items[i].itemId)
      if (qualities.indexOf(items[i].quality) < 0) qualities.push(items[i].quality)
    }
    priceProc.city = city
    priceProc.keys = set.pieces.map(function(p) { return Bz.priceKey(p) })
    priceText = "Consultando el mercado…"
    priceProc.command = ["curl", "-fsS", "--max-time", "10", Prices.buildUrl(ids, city, "west", qualities)]
    priceProc.running = true
  }

  function applyDeathPrices(text) {
    var result = Prices.parseQualityPrices(text, priceProc.city, priceProc.keys)
    if (!result.ok) { priceText = "No pude consultar el mercado. Escribe el valor a mano."; return }
    deathPrices = result.prices
    deathValueField.text = String(pricedValue())
    var missing = missingPrices()
    priceText = "Precios de " + priceProc.city + " (pueden estar desactualizados)."
      + (missing > 0 ? " " + missing + " pieza(s) sin precio: revisa el total." : "")
  }

  function saveDeath() {
    var typed = deathValueField.text.trim() === "" ? null : Farm.parseInteger(deathValueField.text)
    if (deathValueField.text.trim() !== "" && typed === null) { errorText = "El valor perdido debe ser un número entero."; return }
    if (typed === null && pricedValue() === 0) { errorText = "Consulta los precios o escribe el valor perdido."; return }
    var input = { setId: deathSetId, now: Date.now(), id: newId("d"), prices: deathPrices }
    if (typed !== null) input.value = typed
    if (commit(Bz.logDeath(blackzone, input))) {
      deathPrices = ({})
      priceText = ""
      deathValueField.text = ""
      deathOpen = false
    }
  }

  // ---------- Loot ----------

  function saveLoot() {
    var value = Farm.parseInteger(lootValueField.text)
    if (value === null) { errorText = "El valor del botín debe ser un número entero."; return }
    if (commit(Bz.logLoot(blackzone, { value: value, note: lootNoteField.text, now: Date.now(), id: newId("l") }))) {
      lootValueField.text = ""
      lootNoteField.text = ""
      lootOpen = false
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

  Process {
    id: priceProc
    property string city: ""
    property var keys: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyDeathPrices(text)
    }
  }

  // ---------- Summary ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: "ZONA NEGRA"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: (view.sums.profit > 0 ? "Ganancia: " : "Balance: ") + view.signed(view.sums.profit) + " plata"
      color: view.sums.profit < 0 ? Color.urgent : owner.bar.foreground
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: "Ganado: " + Farm.formatSilver(view.sums.loot) + " (" + view.sums.loots + " botín/es)"
        + "\nPerdido: " + Farm.formatSilver(view.sums.lost) + " (" + view.sums.deaths + " muerte(s))"
        + (view.sums.lootPerDeath !== null ? "\nBotín medio por muerte: " + Farm.formatSilver(view.sums.lootPerDeath) : "")
      color: owner.bar.foreground
      opacity: 0.7
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  // ---------- Sets ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(setsHeader.implicitHeight, setsToggle.implicitHeight)

      PanelSectionHeader {
        id: setsHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "SETS"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: setsToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: view.setsOpen ? "Ocultar" : "Mostrar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: view.setsOpen = !view.setsOpen
      }
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
                onAccepted: view.renameSet()
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
                onClicked: view.renameSet()
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
              onAccepted: view.addPiece()
              Keys.onEscapePressed: view.catcher.forceActiveFocus()
            }

            Button {
              text: "Agregar pieza"
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: view.addPiece()
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
    }
  }

  // ---------- Death ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(deathHeader.implicitHeight, deathToggle.implicitHeight)

      PanelSectionHeader {
        id: deathHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "REGISTRAR MUERTE"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: deathToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: view.deathOpen ? "Ocultar" : "Mostrar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: view.toggleDeath()
      }
    }

    Column {
      visible: view.deathOpen
      width: parent.width
      spacing: Style.space(8)

      Text {
        visible: view.blackzone.sets.length === 0
        width: parent.width
        text: "Crea un set con piezas primero."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Column {
        visible: view.blackzone.sets.length > 0
        width: parent.width
        spacing: Style.space(8)

        Dropdown {
          id: deathSetDropdown
          width: parent.width
          label: "Set"
          value: view.deathSetId
          options: view.blackzone.sets.map(function(s) { return { value: s.id, label: s.name } })
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          onChanged: function(v) { view.setDeathSet(v) }
        }

        Row {
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
            onChanged: function(v) { view.city = v }
          }

          Button {
            id: priceButton
            text: "Consultar precios"
            anchors.verticalCenter: cityDropdown.verticalCenter
            foreground: owner.bar.foreground
            fontFamily: owner.bar.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            onClicked: view.fetchDeathPrices()
          }
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

        TextField {
          id: deathValueField
          width: parent.width
          placeholderText: "Valor perdido (plata)"
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: owner.bar.foreground
          onAccepted: view.saveDeath()
          Keys.onEscapePressed: view.catcher.forceActiveFocus()
        }

        Button {
          text: "Guardar muerte"
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.saveDeath()
        }
      }
    }
  }

  // ---------- Loot ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(lootHeader.implicitHeight, lootToggle.implicitHeight)

      PanelSectionHeader {
        id: lootHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "REGISTRAR BOTÍN"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: lootToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: view.lootOpen ? "Ocultar" : "Mostrar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: view.lootOpen = !view.lootOpen
      }
    }

    Column {
      visible: view.lootOpen
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: lootValueField
        width: parent.width
        placeholderText: "Valor del botín (plata)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: lootNoteField.forceActiveFocus()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
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

  // ---------- History ----------
  Column {
    visible: view.history.length > 0
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(historyHeader.implicitHeight, historyToggle.implicitHeight)

      PanelSectionHeader {
        id: historyHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "HISTORIAL"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: historyToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: view.historyOpen ? "Ocultar" : "Mostrar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: view.historyOpen = !view.historyOpen
      }
    }

    Repeater {
      model: view.historyOpen ? view.history : []

      Item {
        id: historyRow
        required property var modelData
        readonly property bool isDeath: modelData.type === "death"
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
              : "Botín" + (historyRow.modelData.note !== "" ? " · " + historyRow.modelData.note : ""))
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
          text: view.signed(historyRow.isDeath ? -historyRow.modelData.value : historyRow.modelData.value)
          color: historyRow.isDeath ? Color.urgent : owner.bar.foreground
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
  }
}
