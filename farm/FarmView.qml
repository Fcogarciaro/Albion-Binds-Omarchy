import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices
import "Planner.js" as Planner
import "../components"

// "Cultivos" tab: capture first. Summary, one card per plot with a single
// contextual button (Plantar / Cosechar) that opens its compose card, the latest
// cycles and, collapsed at the bottom, add plot, planner and tax.
// Data lives in owner.store (DataStore); every change is saved right away.
Column {
  id: view

  required property var owner
  // Item that takes focus back when a text field is dismissed with Esc.
  property Item catcher: null
  // Two-column layout, used by the large window. The bar panel keeps one column.
  property bool wide: false

  readonly property var store: owner.store
  readonly property var farm: store.document.farm
  readonly property real taxRate: farm.settings.taxRate
  readonly property var sums: Farm.totals(farm, taxRate)
  // Latest cycles: 3 by default, more when expanded (always in the wide window).
  readonly property bool historyExpanded: wide || historyAll
  readonly property int historyLimit: historyExpanded ? (wide ? 20 : 8) : 3
  readonly property var history: Farm.closedCycles(farm, historyLimit)
  readonly property int closedCount: sums.overall.cycles
  // Plots still growing / ready to harvest. nowMs ticks so "ready" shows up without a reload.
  property real nowMs: Date.now()
  readonly property int growingCount: countState("planted")
  readonly property int readyCount: countState("ready")

  // Brief confirmation after a save ("" = hidden); cleared by savedTimer.
  property string savedText: ""
  // "Ver todo" in the narrow panel.
  property bool historyAll: false
  // Secondary sections stay collapsed until asked for.
  property bool addPlotOpen: false
  property bool taxOpen: false

  // "" = no form open; otherwise the plot the form acts on.
  property string activePlotId: ""
  property string activeMode: "plant"
  property string plantCrop: "turnip"
  // City shared by the prefill, the planner and the black zone deaths: remembered in the data file.
  readonly property string city: store.document.ui.city
  readonly property string server: store.document.ui.server
  property string errorText: ""
  property string priceText: ""
  // The form price request in flight and the one the user last asked for. An
  // answer is applied only if it still matches the open form.
  property var priceInFlight: null
  property bool priceWanted: false
  // Delete control awaiting its second tap ("plot:<id>", "open:<id>", "hist:<id>").
  property string confirmKey: ""
  // Rotation planner: collapsible, prices fetched on demand for plannerCity.
  property bool plannerOpen: false
  readonly property string plannerCity: city
  property var plannerPrices: ({})
  property string plannerStatus: ""
  property bool plannerFailed: false
  readonly property string plannerKey: plannerCity + "|" + server
  readonly property var plannerRows: Planner.rankCrops(farm, plannerPrices, Farm.CROPS)
  readonly property var activeCycle: activePlotId !== "" ? Farm.openCycle(farm, activePlotId) : null
  readonly property bool editing: plotNameField.activeFocus || seedsField.activeFocus || seedPriceField.activeFocus
    || harvestedField.activeFocus || returnedField.activeFocus || cropPriceField.activeFocus
    || taxField.activeFocus || seedsPlotField.activeFocus || cropDropdown.popupOpen || cityDropdown.popupOpen
    || plannerCityDropdown.popupOpen || plannerServerDropdown.popupOpen

  readonly property var cropOptions: Farm.CROPS.map(function(c) {
    return { value: c.key, label: "T" + c.tier + " " + c.name }
  })

  spacing: Style.space(14)

  function countState(state) {
    var count = 0
    for (var i = 0; i < farm.plots.length; i++)
      if (Farm.plotState(farm, farm.plots[i].id, nowMs) === state) count++
    return count
  }

  // Successful save: flashes "Guardado" (the form, if any, closes on its own).
  function flashSaved() {
    savedText = "Guardado"
    savedTimer.restart()
  }

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

  // Remembers form choices (city) in the data file's ui section.
  function rememberUi(patch) {
    var next = Object.assign({}, store.document)
    next.ui = Object.assign({}, store.document.ui, patch)
    store.document = next
    store.saveData()
  }

  function setCity(value) { rememberUi({ city: value }) }
  function setServer(value) { rememberUi({ server: value }) }

  // Focus goes to the form's first field once its section is visible.
  function focusForm() {
    Qt.callLater(function() {
      if (activePlotId === "") return
      if (activeMode === "plant") seedsField.forceActiveFocus()
      else harvestedField.forceActiveFocus()
    })
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

  // Opens the plot's compose card; tapping its button again closes it.
  function openForm(plotId, mode) {
    if (activePlotId === plotId && activeMode === mode) { closeForm(); return }
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
    focusForm()
  }

  function closeForm() {
    confirmKey = ""
    activePlotId = ""
    errorText = ""
    priceText = ""
    if (catcher) catcher.forceActiveFocus()
  }

  function saved() {
    closeForm()
    flashSaved()
  }

  function addPlot() {
    if (commit(Farm.addPlot(farm, plotNameField.text, newId("p")))) {
      plotNameField.text = ""
      flashSaved()
    }
  }

  function plant() {
    var seeds = Farm.parseInteger(seedsField.text)
    var price = seedPriceField.text.trim() === "" ? 0 : Farm.parseSilver(seedPriceField.text)
    if (seeds === null) { errorText = "Las semillas plantadas deben ser un número entero mayor que 0."; return }
    if (price === null) { errorText = "Precio no válido. Usa un número entero o 450k, 1.2m (un decimal solo con k o m)."; return }
    if (commit(Farm.plantCycle(farm, {
      plotId: activePlotId, crop: plantCrop, seedsPlanted: seeds, seedPrice: price,
      now: Date.now(), id: newId("c")
    }))) saved()
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
    }))) saved()
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
    if (commit(Farm.setTaxRate(farm, rate))) {
      taxField.text = Farm.formatPercent(rate)
      flashSaved()
    }
  }

  // What the open form is asking a price for (null when there is no form).
  function priceRequest() {
    if (activePlotId === "" || (activeMode !== "plant" && activeMode !== "harvest")) return null
    var crop = Farm.cropByKey(activeMode === "plant" ? plantCrop : (activeCycle ? activeCycle.crop : ""))
    if (!crop) return null
    return {
      city: city, server: server, plotId: activePlotId, mode: activeMode,
      itemId: activeMode === "plant" ? crop.seedId : crop.cropId
    }
  }

  // Market prefill: failures only set a message, logging is never blocked.
  function fetchPrice() {
    if (!priceRequest()) return
    priceWanted = true
    priceText = "Consultando el mercado…"
    if (!priceProc.running) startPriceRequest()
  }

  function startPriceRequest() {
    var req = priceRequest()
    if (!req) { priceWanted = false; priceText = ""; return }
    priceInFlight = req
    priceProc.command = Prices.curlArgs(Prices.buildUrl([req.itemId], req.city, req.server), 8)
    priceProc.running = true
  }

  function applyPrice(text) {
    var req = priceInFlight
    priceInFlight = null
    var current = priceRequest()
    if (!Prices.sameRequest(req, current)) {
      // The city, plot, crop or form changed while the request ran: drop the
      // answer, and ask again if the user had asked for the current form.
      if (current && priceWanted) startPriceRequest()
      else priceText = ""
      return
    }
    priceWanted = false
    var checked = Prices.checkResponse(text, "No pude consultar el mercado. Escribe el precio a mano.")
    if (!checked.ok) { priceText = checked.error; return }
    var result = Prices.parsePrices(checked.body, req.city, [req.itemId])
    if (!result.ok) { priceText = "No pude consultar el mercado. Escribe el precio a mano."; return }
    var price = result.prices[req.itemId]
    if (price === null || price === undefined) {
      priceText = "Sin datos de mercado en " + req.city + ". Escribe el precio a mano."
      return
    }
    if (req.mode === "plant") seedPriceField.text = String(price)
    else cropPriceField.text = String(price)
    priceText = "Precio en " + req.city + ": " + Farm.formatSilver(price) + " (puede estar desactualizado)."
  }

  // A new city or server makes the price line on the open form stale.
  onCityChanged: priceText = ""
  onServerChanged: priceText = ""

  function togglePlanner() {
    plannerOpen = !plannerOpen
    if (plannerOpen && (plannerStatus === "" || plannerFailed)) fetchPlannerPrices()
  }

  function plannerIds() {
    var ids = []
    for (var i = 0; i < Farm.CROPS.length; i++) ids.push(Farm.CROPS[i].cropId, Farm.CROPS[i].seedId)
    return ids
  }

  function plannerRequest() { return { city: plannerCity, server: server } }

  // One request for every crop and seed; failures only set a message.
  function fetchPlannerPrices() {
    if (plannerProc.running) return
    plannerStatus = "Consultando el mercado…"
    plannerFailed = false
    plannerProc.req = plannerRequest()
    plannerProc.command = Prices.curlArgs(Prices.buildUrl(plannerIds(), plannerProc.req.city, plannerProc.req.server), 10)
    plannerProc.running = true
  }

  function applyPlannerPrices(text) {
    var req = plannerProc.req
    if (!Prices.sameRequest(req, plannerRequest())) {
      // The city or server changed while the request ran: never show the old
      // answer. The change handler already reset the status; refetch if open.
      plannerStatus = ""
      if (plannerOpen) fetchPlannerPrices()
      return
    }
    var checked = Prices.checkResponse(text, "No pude consultar el mercado. Intenta de nuevo.")
    var result = checked.ok ? Prices.parsePrices(checked.body, req.city, plannerIds()) : null
    if (!result || !result.ok) {
      plannerStatus = checked.ok ? "No pude consultar el mercado. Intenta de nuevo." : checked.error
      plannerFailed = true
      return
    }
    plannerPrices = result.prices
    plannerStatus = "Precios de " + req.city + " (pueden estar desactualizados)."
  }

  function setPlannerCity(value) {
    setCity(value)
  }

  // A new city or server (picked here, in the form or synced from another PC)
  // invalidates the planner prices. Resetting the status makes the next open
  // fetch even while the planner is closed.
  onPlannerKeyChanged: {
    plannerPrices = ({})
    plannerStatus = ""
    plannerFailed = false
    if (plannerOpen) fetchPlannerPrices()
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

  Timer {
    id: savedTimer
    interval: 2000
    onTriggered: view.savedText = ""
  }

  Timer {
    interval: 60000
    repeat: true
    running: view.visible
    onTriggered: view.nowMs = Date.now()
  }

  // An armed delete control disarms itself if the second tap never comes.
  Timer {
    id: confirmTimer
    interval: 4000
    onTriggered: view.confirmKey = ""
  }

  Process {
    id: priceProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyPrice(text)
    }
  }

  Process {
    id: plannerProc
    property var req: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: view.applyPlannerPrices(text)
    }
  }

  // Large window: two lanes side by side. Sections below move into them when
  // `wide`; otherwise they stay direct children of this Column, as before.
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
      implicitHeight: Math.max(totalText.implicitHeight, savedLabel.implicitHeight)

      Text {
        id: totalText
        anchors.left: parent.left
        anchors.right: savedLabel.visible ? savedLabel.left : parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: view.closedCount === 0
          ? "Aún no hay ciclos cerrados."
          : "Ganancia total: " + view.signed(view.sums.overall.profit) + " plata en " + view.closedCount + " ciclo(s)"
        color: view.sums.overall.profit < 0 ? Color.urgent : owner.bar.foreground
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
        label: "Parcelas"
        value: String(view.farm.plots.length)
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Stat {
        width: (parent.width - 2 * parent.spacing) / 3
        label: "Creciendo"
        value: String(view.growingCount)
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Stat {
        width: (parent.width - 2 * parent.spacing) / 3
        label: "Listas"
        value: String(view.readyCount)
        valueColor: view.readyCount > 0 ? Color.accent : owner.bar.foreground
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }
    }
  }

  // ---------- Plots ----------
  Column {
    parent: view.wide ? leftLane : view
    width: parent.width
    spacing: Style.space(8)

    Text {
      visible: view.farm.plots.length === 0
      width: parent.width
      text: "Sin parcelas. Agrega una en «Agregar parcela», abajo."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: view.farm.plots

      BorderSurface {
        id: plotRow
        required property var modelData
        readonly property var cycle: Farm.openCycle(view.farm, modelData.id)
        readonly property string plotStatus: Farm.plotState(view.farm, modelData.id, view.nowMs)
        readonly property var total: view.sums.byPlot[modelData.id]
        readonly property bool formOpen: view.activePlotId === modelData.id
        // The "⋯" area with the two-tap secondary actions.
        property bool moreOpen: false
        width: parent.width
        radius: Style.cornerRadius
        color: plotRow.formOpen ? Style.selectedFill : Style.normalFill
        borderSpec: Border.controlSpec("normal", owner.bar.foreground, Color.accent)
        padding: Style.space(10)
        implicitHeight: plotInner.implicitHeight + contentTopInset + contentBottomInset

        Column {
          id: plotInner
          x: plotRow.contentLeftInset
          y: plotRow.contentTopInset
          width: plotRow.width - plotRow.contentLeftInset - plotRow.contentRightInset
          spacing: Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(plotLabels.implicitHeight, plotActions.implicitHeight)

            Column {
              id: plotLabels
              anchors.left: parent.left
              anchors.right: plotActions.left
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
                text: Farm.plotStateLabel(plotRow.plotStatus) + (plotRow.cycle ? " · " + view.cropName(plotRow.cycle.crop) : "")
                color: plotRow.plotStatus === "ready" ? Color.accent : owner.bar.foreground
                opacity: plotRow.plotStatus === "empty" ? 0.6 : 1
                font.family: owner.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: plotRow.plotStatus === "ready"
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                visible: plotRow.cycle !== null
                textFormat: Text.PlainText
                text: plotRow.cycle ? Farm.formatSilver(plotRow.cycle.seedsPlanted) + " semillas · desde " + view.shortDate(plotRow.cycle.plantedAt) : ""
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

            Row {
              id: plotActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Button {
                text: plotRow.cycle ? "Cosechar" : "Plantar"
                width: Math.max(implicitWidth, Style.space(92))
                selected: plotRow.formOpen
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                onClicked: view.openForm(plotRow.modelData.id, plotRow.cycle ? "harvest" : "plant")
              }

              Button {
                text: "⋯"
                tooltipText: "Más acciones"
                selected: plotRow.moreOpen
                foreground: owner.bar.foreground
                fontFamily: owner.bar.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: { view.confirmKey = ""; plotRow.moreOpen = !plotRow.moreOpen }
              }
            }
          }

          Row {
            visible: plotRow.moreOpen
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
      }
    }

    // ---------- Plant / harvest compose card ----------
    ComposeCard {
      visible: view.activePlotId !== ""
      width: parent.width
      title: (view.activeMode === "plant" ? "Plantar · " : "Cosechar · ") + view.plotName(view.activePlotId)
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      onCloseRequested: view.closeForm()

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
          onChanged: function(v) { view.setCity(v) }
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

      Button {
        text: view.activeMode === "plant" ? "Guardar siembra" : "Guardar cosecha"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: view.activeMode === "plant" ? view.plant() : view.harvest()
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

  // ---------- Latest cycles ----------
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
        text: view.wide ? "HISTORIAL" : "ÚLTIMOS CICLOS"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Button {
        id: historyToggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !view.wide && view.closedCount > 3
        text: view.historyAll ? "Ver menos ‹" : "Ver todo ›"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        fontSize: Style.font.caption
        onClicked: view.historyAll = !view.historyAll
      }
    }

    Text {
      visible: view.closedCount === 0
      width: parent.width
      text: "Aún no hay ciclos cerrados. Planta una parcela y cosecha para ver tu ganancia."
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

    Text {
      visible: view.historyExpanded && view.closedCount > view.historyLimit
      width: parent.width
      text: "Mostrando los últimos " + view.historyLimit + " de " + view.closedCount + "."
      color: owner.bar.foreground
      opacity: 0.6
      font.family: owner.bar.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---------- Collapsed at the bottom: add plot, planner, tax ----------
  Column {
    parent: view.wide ? leftLane : view
    width: parent.width
    spacing: Style.space(8)

    PanelSeparator { foreground: owner.bar.foreground }

    Button {
      width: parent.width
      leftAlign: true
      text: "Agregar parcela " + (view.addPlotOpen ? "⌄" : "›")
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: view.addPlotOpen = !view.addPlotOpen
    }

    Column {
      visible: view.addPlotOpen
      width: parent.width
      spacing: Style.space(8)

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

    Button {
      width: parent.width
      leftAlign: true
      text: "Planificador " + (view.plannerOpen ? "⌄" : "›")
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: view.togglePlanner()
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

      Dropdown {
        id: plannerServerDropdown
        width: parent.width
        label: "Servidor"
        value: view.server
        options: Prices.SERVER_OPTIONS
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        onChanged: function(v) { view.setServer(v) }
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

    Button {
      width: parent.width
      leftAlign: true
      text: "Impuesto de venta " + (view.taxOpen ? "⌄" : "›")
      foreground: owner.bar.foreground
      fontFamily: owner.bar.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: view.taxOpen = !view.taxOpen
    }

    Column {
      visible: view.taxOpen
      width: parent.width
      spacing: Style.space(8)

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
}
