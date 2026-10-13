import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices
import "Planner.js" as Planner
import "../shared/ViewHelpers.js" as Helpers
import "../components"

// "Cultivos" tab: capture first. Summary, one card per plot with a single
// contextual button (Plantar / Cosechar) that opens its compose card, the latest
// cycles and, collapsed at the bottom, add plot, planner and tax.
// Data lives in owner.store (DataStore); every change is saved right away.
// This file holds the state and logic; the pieces live in PlotCard,
// PlantHarvestForm, FarmSummary, FarmAddPlot, FarmPlanner, FarmTax and the
// shared HistoryList.
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
  readonly property var historyRows: history.map(function(c) {
    var profit = Farm.cycleProfit(c, taxRate)
    return {
      id: c.id,
      label: Helpers.shortDate(c.harvestedAt) + " · " + plotName(c.plotId) + " · " + cropName(c.crop),
      valueText: Farm.signed(profit),
      urgent: profit < 0
    }
  })
  // Plots still growing / ready to harvest. nowMs ticks so "ready" shows up without a reload.
  property real nowMs: Date.now()
  readonly property int growingCount: countState("planted")
  readonly property int readyCount: countState("ready")

  // Brief confirmation after a save ("" = hidden).
  readonly property string savedText: notice.text
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
  // Rotation planner: collapsible, prices fetched on demand for plannerCity.
  property bool plannerOpen: false
  readonly property string plannerCity: city
  property var plannerPrices: ({})
  property string plannerStatus: ""
  property bool plannerFailed: false
  readonly property string plannerKey: plannerCity + "|" + server
  readonly property var plannerRows: Planner.rankCrops(farm, plannerPrices, Farm.CROPS)
  readonly property var activeCycle: activePlotId !== "" ? Farm.openCycle(farm, activePlotId) : null
  readonly property bool editing: form.editing || addPlotSection.editing || planner.editing || taxSection.editing
  // Estimated profit shown while filling the harvest form.
  readonly property var harvestPreviewValue: activeMode === "harvest" ? harvestPreview() : null

  readonly property var cropOptions: Farm.CROPS.map(function(c) {
    return { value: c.key, label: "T" + c.tier + " " + c.name }
  })

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

  function countState(state) {
    var count = 0
    for (var i = 0; i < farm.plots.length; i++)
      if (Farm.plotState(farm, farm.plots[i].id, nowMs) === state) count++
    return count
  }

  // Successful save: flashes "Guardado" (the form, if any, closes on its own).
  function flashSaved() {
    notice.flash()
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
      form.focusFirst()
    })
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
    deletes.reset()
    activePlotId = plotId
    activeMode = mode
    errorText = ""
    priceText = ""
    form.clear()
    focusForm()
  }

  function closeForm() {
    deletes.reset()
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
    if (commit(Farm.addPlot(farm, addPlotSection.name, Helpers.newId("p")))) {
      addPlotSection.name = ""
      flashSaved()
    }
  }

  function plant() {
    var seeds = Farm.parseInteger(form.seedsText)
    var price = form.seedPriceText.trim() === "" ? 0 : Farm.parseSilver(form.seedPriceText)
    if (seeds === null) { errorText = "Las semillas plantadas deben ser un número entero mayor que 0."; return }
    if (price === null) { errorText = "Precio no válido. Usa un número entero o 450k, 1.2m (un decimal solo con k o m)."; return }
    if (commit(Farm.plantCycle(farm, {
      plotId: activePlotId, crop: plantCrop, seedsPlanted: seeds, seedPrice: price,
      now: Date.now(), id: Helpers.newId("c")
    }))) saved()
  }

  function harvest() {
    var crops = Farm.parseInteger(form.harvestedText)
    var returned = form.returnedText.trim() === "" ? 0 : Farm.parseInteger(form.returnedText)
    var price = form.cropPriceText.trim() === "" ? 0 : Farm.parseSilver(form.cropPriceText)
    if (crops === null) { errorText = "Escribe cuántos cultivos cosechaste (0 si se perdieron)."; return }
    if (returned === null || price === null) { errorText = "Semillas devueltas: número entero. Precio: número entero o 450k, 1.2m."; return }
    if (commit(Farm.harvestCycle(farm, {
      cycleId: activeCycle ? activeCycle.id : "", cropsHarvested: crops, seedsReturned: returned,
      cropPrice: price, now: Date.now()
    }))) saved()
  }

  function harvestPreview() {
    if (!activeCycle) return null
    var crops = Farm.parseInteger(form.harvestedText)
    if (crops === null) return null
    var returned = Farm.parseInteger(form.returnedText) || 0
    var price = Farm.parseSilver(form.cropPriceText) || 0
    return Farm.cycleProfit({
      seedsPlanted: activeCycle.seedsPlanted, seedPrice: activeCycle.seedPrice, harvestedAt: 1,
      cropsHarvested: crops, seedsReturned: returned, cropPrice: price
    }, taxRate)
  }

  function saveTax() {
    var rate = Farm.parsePercent(taxSection.text)
    if (rate === null) { errorText = "El impuesto debe ser un porcentaje entre 0 y 100."; return }
    if (commit(Farm.setTaxRate(farm, rate))) {
      taxSection.text = Farm.formatPercent(rate)
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
    if (req.mode === "plant") form.seedPriceText = String(price)
    else form.cropPriceText = String(price)
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
    var n = Farm.parseInteger(planner.seedsText)
    if (n === null) { errorText = "Las semillas por parcela deben ser un número entero."; return }
    if (commit(Farm.setPlannerSettings(farm, { seedsPerPlot: n }))) planner.seedsText = String(n)
  }

  Timer {
    interval: 60000
    repeat: true
    running: view.visible
    onTriggered: view.nowMs = Date.now()
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

  // Large window: summary and history go right, capture goes left.
  LaneLayout {
    id: lanes
    width: parent.width
    wide: view.wide
    laneSpacing: look.gapLane
    sectionSpacing: view.spacing
  }

  // ---------- Summary ----------
  FarmSummary {
    parent: view.wide ? lanes.rightLane : view
    width: parent.width
    theme: look
    totalText: view.closedCount === 0
      ? "Aún no hay ciclos cerrados."
      : "Ganancia total: " + Farm.signed(view.sums.overall.profit) + " plata en " + view.closedCount + " ciclo(s)"
    urgent: view.sums.overall.profit < 0
    savedText: view.savedText
    plotCount: view.farm.plots.length
    growingCount: view.growingCount
    readyCount: view.readyCount
  }

  // ---------- Plots ----------
  Column {
    parent: view.wide ? lanes.leftLane : view
    width: parent.width
    spacing: look.gap

    ViewText {
      visible: view.farm.plots.length === 0
      width: parent.width
      theme: look
      tone: "secondary"
      text: "Sin parcelas. Agrega una en «Agregar parcela», abajo."
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: view.farm.plots

      PlotCard {
        id: plotRow
        required property var modelData
        width: parent.width
        theme: look
        confirm: deletes
        plot: plotRow.modelData
        cycle: Farm.openCycle(view.farm, plotRow.modelData.id)
        status: Farm.plotState(view.farm, plotRow.modelData.id, view.nowMs)
        cropLabel: plotRow.cycle ? view.cropName(plotRow.cycle.crop) : ""
        total: view.sums.byPlot[plotRow.modelData.id]
        formOpen: view.activePlotId === plotRow.modelData.id
        onActionRequested: view.openForm(plotRow.modelData.id, plotRow.cycle ? "harvest" : "plant")
        onCancelCycleRequested: view.removeCycle(plotRow.cycle.id)
        onRemoveRequested: view.removePlot(plotRow.modelData.id)
      }
    }

    // ---------- Plant / harvest compose card ----------
    PlantHarvestForm {
      id: form
      visible: view.activePlotId !== ""
      width: parent.width
      theme: look
      catcher: view.catcher
      title: (view.activeMode === "plant" ? "Plantar · " : "Cosechar · ") + view.plotName(view.activePlotId)
      mode: view.activeMode
      cropOptions: view.cropOptions
      crop: view.plantCrop
      cycleInfo: view.activeCycle
        ? view.cropName(view.activeCycle.crop) + " · " + Farm.formatSilver(view.activeCycle.seedsPlanted)
          + " semillas a " + Farm.formatSilver(view.activeCycle.seedPrice) + " c/u"
        : ""
      city: view.city
      priceText: view.priceText
      preview: view.harvestPreviewValue
      onCloseRequested: view.closeForm()
      onCropPicked: function(v) { view.plantCrop = v }
      onCityPicked: function(v) { view.setCity(v) }
      onPriceRequested: view.fetchPrice()
      onPlantRequested: view.plant()
      onHarvestRequested: view.harvest()
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

  // ---------- Latest cycles ----------
  HistoryList {
    parent: view.wide ? lanes.rightLane : view
    width: parent.width
    theme: look
    confirm: deletes
    title: view.wide ? "HISTORIAL" : "ÚLTIMOS CICLOS"
    emptyText: "Aún no hay ciclos cerrados. Planta una parcela y cosecha para ver tu ganancia."
    rows: view.historyRows
    keyPrefix: "hist:"
    wide: view.wide
    canExpand: view.closedCount > 3
    expanded: view.historyAll
    footerText: view.historyExpanded && view.closedCount > view.historyLimit
      ? "Mostrando los últimos " + view.historyLimit + " de " + view.closedCount + "." : ""
    onToggleRequested: view.historyAll = !view.historyAll
    onDeleteRequested: function(id) { view.removeCycle(id) }
  }

  // ---------- Collapsed at the bottom: add plot, planner, tax ----------
  Column {
    parent: view.wide ? lanes.leftLane : view
    width: parent.width
    spacing: look.gap

    PanelSeparator { foreground: look.foreground }

    FarmAddPlot {
      id: addPlotSection
      width: parent.width
      theme: look
      catcher: view.catcher
      open: view.addPlotOpen
      onToggled: view.addPlotOpen = !view.addPlotOpen
      onAddRequested: view.addPlot()
    }

    FarmPlanner {
      id: planner
      width: parent.width
      theme: look
      catcher: view.catcher
      open: view.plannerOpen
      city: view.plannerCity
      server: view.server
      premium: view.farm.settings.premium
      useFocus: view.farm.settings.focus
      seedsPerPlot: view.farm.settings.seedsPerPlot
      status: view.plannerStatus
      rows: view.plannerRows
      onToggled: view.togglePlanner()
      onCityPicked: function(v) { view.setCity(v) }
      onServerPicked: function(v) { view.setServer(v) }
      onRefreshRequested: view.fetchPlannerPrices()
      onPremiumToggled: view.savePlannerSetting({ premium: !view.farm.settings.premium })
      onFocusToggled: view.savePlannerSetting({ focus: !view.farm.settings.focus })
      onSeedsSaveRequested: view.saveSeedsPerPlot()
    }

    FarmTax {
      id: taxSection
      width: parent.width
      theme: look
      catcher: view.catcher
      open: view.taxOpen
      taxRate: view.taxRate
      onToggled: view.taxOpen = !view.taxOpen
      onSaveRequested: view.saveTax()
    }
  }
}
