import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices
import "Planner.js" as Planner

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
  // Delete control awaiting its second tap ("plot:<id>", "open:<id>", "hist:<id>").
  property string confirmKey: ""
  // Rotation planner: collapsible, prices fetched on demand for plannerCity.
  property bool plannerOpen: false
  property string plannerCity: "Lymhurst"
  property var plannerPrices: ({})
  property string plannerStatus: ""
  readonly property var plannerRows: Planner.rankCrops(farm, plannerPrices, Farm.CROPS)
  readonly property var activeCycle: activePlotId !== "" ? Farm.openCycle(farm, activePlotId) : null
  readonly property bool editing: plotNameField.activeFocus || seedsField.activeFocus || seedPriceField.activeFocus
    || harvestedField.activeFocus || returnedField.activeFocus || cropPriceField.activeFocus
    || taxField.activeFocus || seedsPlotField.activeFocus || cropDropdown.popupOpen || cityDropdown.popupOpen
    || plannerCityDropdown.popupOpen

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

  function removePlot(plotId) {
    if (commit(Farm.removePlot(farm, plotId)) && activePlotId === plotId) closeForm()
  }

  function removeCycle(cycleId) {
    var current = activeCycle
    if (commit(Farm.removeCycle(farm, cycleId)) && current && current.id === cycleId) closeForm()
  }

  function openForm(plotId, mode) {
    confirmKey = ""
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
    confirmKey = ""
    activePlotId = ""
    errorText = ""
    priceText = ""
  }

  function addPlot() {
    if (commit(Farm.addPlot(farm, plotNameField.text, newId("p")))) plotNameField.text = ""
  }

  function plant() {
    var seeds = Farm.parseInteger(seedsField.text)
    var price = seedPriceField.text.trim() === "" ? 0 : Farm.parseSilver(seedPriceField.text)
    if (seeds === null) { errorText = "Las semillas plantadas deben ser un número entero mayor que 0."; return }
    if (price === null) { errorText = "Precio no válido. Usa un número entero o 450k, 1.2m (un decimal solo con k o m)."; return }
    if (commit(Farm.plantCycle(farm, {
      plotId: activePlotId, crop: plantCrop, seedsPlanted: seeds, seedPrice: price,
      now: Date.now(), id: newId("c")
    }))) closeForm()
  }

  function harvest() {
    var crops = Farm.parseInteger(harvestedField.text)
    var returned = returnedField.text.trim() === "" ? 0 : Farm.parseInteger(returnedField.text)
    var price = cropPriceField.text.trim() === "" ? 0 : Farm.parseSilver(cropPriceField.text)
    if (crops === null) { errorText = "Escribe cuántos cultivos cosechaste (0 si se perdieron)."; return }
    if (returned === null || price === null) { errorText = "Semillas devueltas: número entero. Precio: número entero o 450k, 1.2m."; return }
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
    var price = Farm.parseSilver(cropPriceField.text) || 0
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

  function togglePlanner() {
    plannerOpen = !plannerOpen
    if (plannerOpen && plannerStatus === "") fetchPlannerPrices()
  }

  function plannerIds() {
    var ids = []
    for (var i = 0; i < Farm.CROPS.length; i++) ids.push(Farm.CROPS[i].cropId, Farm.CROPS[i].seedId)
    return ids
  }

  // One request for every crop and seed; failures only set a message.
  function fetchPlannerPrices() {
    if (plannerProc.running) return
    plannerStatus = "Consultando el mercado…"
    plannerProc.city = plannerCity
    plannerProc.command = ["curl", "-fsS", "--max-time", "10", Prices.buildUrl(plannerIds(), plannerCity)]
    plannerProc.running = true
  }

  function applyPlannerPrices(text) {
    var result = Prices.parsePrices(text, plannerProc.city, plannerIds())
    if (!result.ok) { plannerStatus = "No pude consultar el mercado. Intenta de nuevo."; return }
    plannerPrices = result.prices
    plannerStatus = "Precios de " + plannerProc.city + " (pueden estar desactualizados)."
  }

  function setPlannerCity(value) {
    plannerCity = value
    plannerPrices = ({})
    fetchPlannerPrices()
  }

  function savePlannerSetting(patch) { commit(Farm.setPlannerSettings(farm, patch)) }

  function saveSeedsPerPlot() {
    var n = Farm.parseInteger(seedsPlotField.text)
    if (n === null) { errorText = "Las semillas por parcela deben ser un número entero."; return }
    if (commit(Farm.setPlannerSettings(farm, { seedsPerPlot: n }))) seedsPlotField.text = String(n)
  }

  function plannerDetail(row) {
    var label = row.source + " · " + (Math.round(row.cropsPerSeed * 100) / 100) + " cultivos/semilla"
    return row.partial ? label + " · sin precio de semilla (parcial)" : label
  }

  // Keeps the fields in sync when the data file finishes loading.
  onTaxRateChanged: if (!taxField.activeFocus) taxField.text = Farm.formatPercent(taxRate)
  readonly property int seedsPerPlot: farm.settings.seedsPerPlot
  onSeedsPerPlotChanged: if (!seedsPlotField.activeFocus) seedsPlotField.text = String(seedsPerPlot)
  Component.onCompleted: {
    taxField.text = Farm.formatPercent(taxRate)
    seedsPlotField.text = String(seedsPerPlot)
  }

  // An armed delete control disarms itself if the second tap never comes.
  Timer {
    id: confirmTimer
    interval: 4000
    onTriggered: view.confirmKey = ""
  }

  Process {
    id: priceProc
    property string wantedId: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyPrice(text)
    }
  }

  Process {
    id: plannerProc
    property string city: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyPlannerPrices(text)
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

          Row {
            spacing: Style.space(6)

            Button {
              visible: plotRow.cycle !== null
              text: view.deleteLabel("open:" + (plotRow.cycle ? plotRow.cycle.id : ""), "Cancelar siembra")
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: view.askDelete("open:" + plotRow.cycle.id, function() { view.removeCycle(plotRow.cycle.id) })
            }

            Button {
              text: view.deleteLabel("plot:" + plotRow.modelData.id, "Eliminar parcela")
              foreground: owner.bar.foreground
              fontFamily: owner.bar.fontFamily
              fontSize: Style.font.caption
              bordered: true
              onClicked: view.askDelete("plot:" + plotRow.modelData.id, function() { view.removePlot(plotRow.modelData.id) })
            }
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

  // ---------- Rotation planner ----------
  Column {
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Item {
      width: parent.width
      implicitHeight: Math.max(plannerHeader.implicitHeight, plannerToggle.implicitHeight)

      PanelSectionHeader {
        id: plannerHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "PLANIFICADOR"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: plannerToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: view.plannerOpen ? "Ocultar" : "Mostrar"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: view.togglePlanner()
      }
    }

    Column {
      visible: view.plannerOpen
      width: parent.width
      spacing: Style.space(8)

      Row {
        width: parent.width
        spacing: Style.space(6)

        Dropdown {
          id: plannerCityDropdown
          width: parent.width - plannerRefresh.width - parent.spacing
          label: "Ciudad"
          value: view.plannerCity
          options: Prices.CITIES
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          onChanged: function(v) { view.setPlannerCity(v) }
        }

        Button {
          id: plannerRefresh
          text: "Actualizar"
          anchors.verticalCenter: plannerCityDropdown.verticalCenter
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.fetchPlannerPrices()
        }
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(premiumLabel.implicitHeight, premiumSwitch.implicitHeight)

        Text {
          id: premiumLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Premium"
          color: owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        ToggleSwitch {
          id: premiumSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: view.farm.settings.premium
          foreground: owner.bar.foreground
          onToggled: view.savePlannerSetting({ premium: !view.farm.settings.premium })
        }
      }

      Item {
        width: parent.width
        implicitHeight: Math.max(focusLabel.implicitHeight, focusSwitch.implicitHeight)

        Text {
          id: focusLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Riego con foco"
          color: owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        ToggleSwitch {
          id: focusSwitch
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          checked: view.farm.settings.focus
          foreground: owner.bar.foreground
          onToggled: view.savePlannerSetting({ focus: !view.farm.settings.focus })
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        TextField {
          id: seedsPlotField
          width: parent.width - seedsPlotButton.width - parent.spacing
          placeholderText: "Semillas por parcela"
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: owner.bar.foreground
          onAccepted: view.saveSeedsPerPlot()
          Keys.onEscapePressed: view.catcher.forceActiveFocus()
        }

        Button {
          id: seedsPlotButton
          text: "Guardar"
          anchors.verticalCenter: seedsPlotField.verticalCenter
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.saveSeedsPerPlot()
        }
      }

      Text {
        visible: view.plannerStatus !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: view.plannerStatus
        color: owner.bar.foreground
        opacity: 0.7
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: view.plannerRows

        Item {
          id: plannerRow
          required property var modelData
          required property int index
          width: parent.width
          implicitHeight: Math.max(plannerLabels.implicitHeight, plannerProfit.implicitHeight)

          Column {
            id: plannerLabels
            anchors.left: parent.left
            anchors.right: plannerProfit.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: (plannerRow.index + 1) + ". T" + plannerRow.modelData.tier + " " + plannerRow.modelData.name
              color: owner.bar.foreground
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: plannerRow.index === 0 && plannerRow.modelData.profit !== null
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: view.plannerDetail(plannerRow.modelData)
              color: owner.bar.foreground
              opacity: 0.6
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: plannerProfit
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: plannerRow.modelData.profit === null ? "sin precio" : view.signed(plannerRow.modelData.profit)
            color: plannerRow.modelData.profit !== null && plannerRow.modelData.profit < 0 ? Color.urgent : owner.bar.foreground
            opacity: plannerRow.modelData.profit === null ? 0.6 : 1
            font.family: owner.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: plannerRow.modelData.profit !== null
          }
        }
      }

      Text {
        width: parent.width
        text: "Ganancia esperada por parcela y ciclo. Estimado = datos del juego, aproximado."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
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
      placeholderText: "Precio por semilla (ej. 450k)"
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
      placeholderText: "Precio por cultivo (ej. 1.2k)"
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
        implicitHeight: Math.max(historyLabel.implicitHeight, historyProfit.implicitHeight, historyDelete.implicitHeight)

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
          anchors.right: historyDelete.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: view.signed(historyRow.profit)
          color: historyRow.profit < 0 ? Color.urgent : owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Button {
          id: historyDelete
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: view.deleteLabel("hist:" + historyRow.modelData.id, "Eliminar")
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.caption
          bordered: true
          onClicked: view.askDelete("hist:" + historyRow.modelData.id, function() { view.removeCycle(historyRow.modelData.id) })
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
