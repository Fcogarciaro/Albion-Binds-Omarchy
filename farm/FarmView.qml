import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices

// "Cultivos" tab: plots, plant/harvest forms, cycle history and totals.
// Data lives in owner.store (DataStore); every change is saved right away.
Column {
  id: view

  required property var owner
  // Item that takes focus back when a text field is dismissed with Esc.
  property Item catcher: null

  readonly property var store: owner.store
  readonly property var farm: store.document.farm
  readonly property real taxRate: farm.settings.taxRate
  readonly property var sums: Farm.totals(farm, taxRate)
  readonly property var history: Farm.closedCycles(farm, 8)

  // "" = no form open; otherwise the plot the form acts on.
  property string activePlotId: ""
  property string activeMode: "plant"
  property string plantCrop: "turnip"
  property string city: "Lymhurst"
  property string errorText: ""
  property string priceText: ""
  property string priceTarget: ""
  readonly property var activeCycle: activePlotId !== "" ? Farm.openCycle(farm, activePlotId) : null
  readonly property bool editing: plotNameField.activeFocus || seedsField.activeFocus || seedPriceField.activeFocus
    || harvestedField.activeFocus || returnedField.activeFocus || cropPriceField.activeFocus
    || taxField.activeFocus || cropDropdown.popupOpen || cityDropdown.popupOpen

  readonly property var cropOptions: Farm.CROPS.map(function(c) {
    return { value: c.key, label: "T" + c.tier + " " + c.name }
  })

  spacing: Style.space(14)

  function plotName(id) {
    var plots = farm.plots
    for (var i = 0; i < plots.length; i++) if (plots[i].id === id) return plots[i].name
    return "?"
  }

  function cropName(key) {
    var crop = Farm.cropByKey(key)
    return crop ? crop.name : key
  }

  function shortDate(ms) { return Qt.formatDate(new Date(ms), "dd/MM") }

  function newId(prefix) {
    return prefix + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
  }

  function signed(n) { return (n > 0 ? "+" : "") + Farm.formatSilver(n) }

  // Applies an operation result: persists it, or shows its error.
  function commit(result) {
    if (!result.ok) { errorText = result.error; return false }
    errorText = ""
    var next = Object.assign({}, store.document)
    next.farm = result.farm
    store.document = next
    store.saveData()
    return true
  }

  function openForm(plotId, mode) {
    activePlotId = plotId
    activeMode = mode
    errorText = ""
    priceText = ""
    seedsField.text = ""
    seedPriceField.text = ""
    harvestedField.text = ""
    returnedField.text = ""
    cropPriceField.text = ""
  }

  function closeForm() {
    activePlotId = ""
    errorText = ""
    priceText = ""
  }

  function addPlot() {
    if (commit(Farm.addPlot(farm, plotNameField.text, newId("p")))) plotNameField.text = ""
  }

  function plant() {
    var seeds = Farm.parseInteger(seedsField.text)
    var price = seedPriceField.text.trim() === "" ? 0 : Farm.parseInteger(seedPriceField.text)
    if (seeds === null) { errorText = "Las semillas plantadas deben ser un número entero mayor que 0."; return }
    if (price === null) { errorText = "El precio de la semilla debe ser un número entero."; return }
    if (commit(Farm.plantCycle(farm, {
      plotId: activePlotId, crop: plantCrop, seedsPlanted: seeds, seedPrice: price,
      now: Date.now(), id: newId("c")
    }))) closeForm()
  }

  function harvest() {
    var crops = Farm.parseInteger(harvestedField.text)
    var returned = returnedField.text.trim() === "" ? 0 : Farm.parseInteger(returnedField.text)
    var price = cropPriceField.text.trim() === "" ? 0 : Farm.parseInteger(cropPriceField.text)
    if (crops === null) { errorText = "Escribe cuántos cultivos cosechaste (0 si se perdieron)."; return }
    if (returned === null || price === null) { errorText = "Semillas devueltas y precio deben ser números enteros."; return }
    if (commit(Farm.harvestCycle(farm, {
      cycleId: activeCycle ? activeCycle.id : "", cropsHarvested: crops, seedsReturned: returned,
      cropPrice: price, now: Date.now()
    }))) closeForm()
  }

  // Estimated profit shown while filling the harvest form.
  function harvestPreview() {
    if (!activeCycle) return null
    var crops = Farm.parseInteger(harvestedField.text)
    if (crops === null) return null
    var returned = Farm.parseInteger(returnedField.text) || 0
    var price = Farm.parseInteger(cropPriceField.text) || 0
    return Farm.cycleProfit({
      seedsPlanted: activeCycle.seedsPlanted, seedPrice: activeCycle.seedPrice, harvestedAt: 1,
      cropsHarvested: crops, seedsReturned: returned, cropPrice: price
    }, taxRate)
  }

  function saveTax() {
    var rate = Farm.parsePercent(taxField.text)
    if (rate === null) { errorText = "El impuesto debe ser un porcentaje entre 0 y 100."; return }
    if (commit(Farm.setTaxRate(farm, rate))) taxField.text = Farm.formatPercent(rate)
  }

  // Market prefill: failures only set a message, logging is never blocked.
  function fetchPrice() {
    if (priceProc.running) return
    var crop = Farm.cropByKey(activeMode === "plant" ? plantCrop : (activeCycle ? activeCycle.crop : ""))
    if (!crop) return
    priceTarget = activeMode
    priceProc.wantedId = activeMode === "plant" ? crop.seedId : crop.cropId
    priceText = "Consultando el mercado…"
    priceProc.command = ["curl", "-fsS", "--max-time", "8", Prices.buildUrl([priceProc.wantedId], city)]
    priceProc.running = true
  }

  function applyPrice(text) {
    var result = Prices.parsePrices(text, city, [priceProc.wantedId])
    if (!result.ok) { priceText = "No pude consultar el mercado. Escribe el precio a mano."; return }
    var price = result.prices[priceProc.wantedId]
    if (price === null || price === undefined) {
      priceText = "Sin datos de mercado en " + city + ". Escribe el precio a mano."
      return
    }
    if (priceTarget === "plant") seedPriceField.text = String(price)
    else cropPriceField.text = String(price)
    priceText = "Precio en " + city + ": " + Farm.formatSilver(price) + " (puede estar desactualizado)."
  }

  // Keeps the field in sync when the data file finishes loading.
  onTaxRateChanged: if (!taxField.activeFocus) taxField.text = Farm.formatPercent(taxRate)
  Component.onCompleted: taxField.text = Farm.formatPercent(taxRate)

  Process {
    id: priceProc
    property string wantedId: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyPrice(text)
    }
  }

  // ---------- Summary ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: "CULTIVOS"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: sums.overall.cycles === 0
        ? "Aún no hay ciclos cerrados."
        : "Ganancia total: " + view.signed(sums.overall.profit) + " plata en " + sums.overall.cycles + " ciclo(s)"
      color: sums.overall.profit < 0 ? Color.urgent : owner.bar.foreground
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }
  }

  // ---------- Plots ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSectionHeader {
      text: "PARCELAS"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Text {
      visible: farm.plots.length === 0
      width: parent.width
      text: "Sin parcelas. Agrega una abajo."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: farm.plots

      Item {
        id: plotRow
        required property var modelData
        readonly property var cycle: Farm.openCycle(view.farm, modelData.id)
        readonly property var total: view.sums.byPlot[modelData.id]
        width: parent.width
        implicitHeight: Math.max(plotLabels.implicitHeight, plotButton.implicitHeight)

        Column {
          id: plotLabels
          anchors.left: parent.left
          anchors.right: plotButton.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: plotRow.modelData.name
            color: owner.bar.foreground
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: plotRow.cycle
              ? view.cropName(plotRow.cycle.crop) + " · " + Farm.formatSilver(plotRow.cycle.seedsPlanted) + " semillas · desde " + view.shortDate(plotRow.cycle.plantedAt)
              : "Libre"
            color: owner.bar.foreground
            opacity: 0.7
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            visible: plotRow.total !== undefined
            textFormat: Text.PlainText
            text: plotRow.total ? "Total: " + view.signed(plotRow.total.profit) + " · " + plotRow.total.cycles + " ciclo(s)" : ""
            color: plotRow.total && plotRow.total.profit < 0 ? Color.urgent : owner.bar.foreground
            opacity: 0.7
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Button {
          id: plotButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: plotRow.cycle ? "Cosechar" : "Plantar"
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.openForm(plotRow.modelData.id, plotRow.cycle ? "harvest" : "plant")
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: plotNameField
        width: parent.width - addPlotButton.width - parent.spacing
        placeholderText: "Nombre de la parcela"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.addPlot()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Button {
        id: addPlotButton
        text: "Agregar"
        anchors.verticalCenter: plotNameField.verticalCenter
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.addPlot()
      }
    }
  }

  // ---------- Plant / harvest form ----------
  Column {
    visible: view.activePlotId !== ""
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    PanelSectionHeader {
      text: (view.activeMode === "plant" ? "PLANTAR · " : "COSECHAR · ") + view.plotName(view.activePlotId).toUpperCase()
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Dropdown {
      id: cropDropdown
      visible: view.activeMode === "plant"
      width: parent.width
      label: "Cultivo"
      value: view.plantCrop
      options: view.cropOptions
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      onChanged: function(v) { view.plantCrop = v }
    }

    Text {
      visible: view.activeMode === "harvest" && view.activeCycle !== null
      width: parent.width
      textFormat: Text.PlainText
      text: view.activeCycle
        ? view.cropName(view.activeCycle.crop) + " · " + Farm.formatSilver(view.activeCycle.seedsPlanted)
          + " semillas a " + Farm.formatSilver(view.activeCycle.seedPrice) + " c/u"
        : ""
      color: owner.bar.foreground
      opacity: 0.7
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    TextField {
      id: seedsField
      visible: view.activeMode === "plant"
      width: parent.width
      placeholderText: "Semillas plantadas"
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      foreground: owner.bar.foreground
      onAccepted: seedPriceField.forceActiveFocus()
      Keys.onEscapePressed: view.catcher.forceActiveFocus()
    }

    TextField {
      id: seedPriceField
      visible: view.activeMode === "plant"
      width: parent.width
      placeholderText: "Precio por semilla (plata)"
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      foreground: owner.bar.foreground
      onAccepted: view.plant()
      Keys.onEscapePressed: view.catcher.forceActiveFocus()
    }

    TextField {
      id: harvestedField
      visible: view.activeMode === "harvest"
      width: parent.width
      placeholderText: "Cultivos cosechados"
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      foreground: owner.bar.foreground
      onAccepted: returnedField.forceActiveFocus()
      Keys.onEscapePressed: view.catcher.forceActiveFocus()
    }

    TextField {
      id: returnedField
      visible: view.activeMode === "harvest"
      width: parent.width
      placeholderText: "Semillas devueltas"
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      foreground: owner.bar.foreground
      onAccepted: cropPriceField.forceActiveFocus()
      Keys.onEscapePressed: view.catcher.forceActiveFocus()
    }

    TextField {
      id: cropPriceField
      visible: view.activeMode === "harvest"
      width: parent.width
      placeholderText: "Precio de venta por cultivo (plata)"
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.body
      foreground: owner.bar.foreground
      onAccepted: view.harvest()
      Keys.onEscapePressed: view.catcher.forceActiveFocus()
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
        text: "Precio de mercado"
        anchors.verticalCenter: cityDropdown.verticalCenter
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.fetchPrice()
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

    Text {
      readonly property var preview: view.activeMode === "harvest" ? view.harvestPreview() : null
      visible: preview !== null
      width: parent.width
      textFormat: Text.PlainText
      text: preview !== null ? "Ganancia estimada: " + view.signed(preview) + " plata" : ""
      color: preview !== null && preview < 0 ? Color.urgent : owner.bar.foreground
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Row {
      spacing: Style.space(6)

      Button {
        text: view.activeMode === "plant" ? "Plantar" : "Cosechar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.activeMode === "plant" ? view.plant() : view.harvest()
      }

      Button {
        text: "Cancelar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.closeForm()
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

    PanelSectionHeader {
      text: "HISTORIAL"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Repeater {
      model: view.history

      Item {
        id: historyRow
        required property var modelData
        readonly property int profit: Farm.cycleProfit(modelData, view.taxRate)
        width: parent.width
        implicitHeight: Math.max(historyLabel.implicitHeight, historyProfit.implicitHeight)

        Text {
          id: historyLabel
          anchors.left: parent.left
          anchors.right: historyProfit.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: view.shortDate(historyRow.modelData.harvestedAt) + " · " + view.plotName(historyRow.modelData.plotId)
            + " · " + view.cropName(historyRow.modelData.crop)
          color: owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          id: historyProfit
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: view.signed(historyRow.profit)
          color: historyRow.profit < 0 ? Color.urgent : owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }
    }
  }

  // ---------- Tax ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    PanelSectionHeader {
      text: "IMPUESTO DE VENTA (%)"
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
    }

    Row {
      width: parent.width
      spacing: Style.space(6)

      TextField {
        id: taxField
        width: parent.width - taxButton.width - parent.spacing
        placeholderText: "6.5"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: view.saveTax()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Button {
        id: taxButton
        text: "Guardar"
        anchors.verticalCenter: taxField.verticalCenter
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.saveTax()
      }
    }

    Text {
      width: parent.width
      text: "6.5 % = 4 % de impuesto con premium + 2.5 % de orden de venta."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }
}
