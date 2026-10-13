import QtQuick
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices
import "../components"

// Collapsed "Planificador" section: crops ranked by expected profit per plot
// and cycle, with the city, server, premium, focus and seeds-per-plot settings.
Column {
  id: root

  required property ViewStyle theme
  property Item catcher: null
  property bool open: false
  property string city: ""
  property string server: ""
  property bool premium: true
  property bool useFocus: true
  property int seedsPerPlot: 9
  property string status: ""
  // Ranked crops from Planner.rankCrops.
  property var rows: []
  property alias seedsText: seedsRow.text
  readonly property bool editing: seedsRow.editing || cityDropdown.popupOpen || serverDropdown.popupOpen

  signal toggled()
  signal cityPicked(string value)
  signal serverPicked(string value)
  signal refreshRequested()
  signal premiumToggled()
  signal focusToggled()
  signal seedsSaveRequested()

  spacing: root.theme.gap

  onSeedsPerPlotChanged: if (!seedsRow.editing) seedsRow.text = String(root.seedsPerPlot)
  Component.onCompleted: seedsRow.text = String(root.seedsPerPlot)

  function detail(entry) {
    var label = entry.source + " · " + (Math.round(entry.cropsPerSeed * 100) / 100) + " cultivos/semilla"
    return entry.partial ? label + " · sin precio de semilla (parcial)" : label
  }

  SectionToggle {
    width: parent.width
    theme: root.theme
    title: "Planificador"
    open: root.open
    onToggled: root.toggled()
  }

  Column {
    visible: root.open
    width: parent.width
    spacing: root.theme.gap

    Row {
      width: parent.width
      spacing: root.theme.gap

      Dropdown {
        id: cityDropdown
        width: parent.width - refreshButton.width - parent.spacing
        label: "Ciudad"
        value: root.city
        options: Prices.CITIES
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
        onChanged: function(v) { root.cityPicked(v) }
      }

      ViewButton {
        id: refreshButton
        anchors.verticalCenter: cityDropdown.verticalCenter
        theme: root.theme
        text: "Actualizar"
        onClicked: root.refreshRequested()
      }
    }

    Dropdown {
      id: serverDropdown
      width: parent.width
      label: "Servidor"
      value: root.server
      options: Prices.SERVER_OPTIONS
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
      onChanged: function(v) { root.serverPicked(v) }
    }

    ToggleRow {
      width: parent.width
      theme: root.theme
      text: "Premium"
      checked: root.premium
      onToggled: root.premiumToggled()
    }

    ToggleRow {
      width: parent.width
      theme: root.theme
      text: "Riego con foco"
      checked: root.useFocus
      onToggled: root.focusToggled()
    }

    FieldRow {
      id: seedsRow
      width: parent.width
      theme: root.theme
      catcher: root.catcher
      placeholderText: "Semillas por parcela"
      buttonText: "Guardar"
      onSubmitted: root.seedsSaveRequested()
    }

    ViewText {
      visible: root.status !== ""
      width: parent.width
      theme: root.theme
      size: "caption"
      tone: "label"
      text: root.status
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: root.rows

      Item {
        id: row
        required property var modelData
        required property int index
        width: parent.width
        implicitHeight: Math.max(labels.implicitHeight, profit.implicitHeight)

        Column {
          id: labels
          anchors.left: parent.left
          anchors.right: profit.left
          anchors.rightMargin: root.theme.gap
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          ViewText {
            width: parent.width
            theme: root.theme
            text: (row.index + 1) + ". T" + row.modelData.tier + " " + row.modelData.name
            font.bold: row.index === 0 && row.modelData.profit !== null
            elide: Text.ElideRight
          }

          ViewText {
            width: parent.width
            theme: root.theme
            size: "caption"
            tone: "secondary"
            text: root.detail(row.modelData)
            elide: Text.ElideRight
          }
        }

        ViewText {
          id: profit
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          theme: root.theme
          tone: row.modelData.profit === null ? "secondary" : "normal"
          text: row.modelData.profit === null ? "sin precio" : Farm.signed(row.modelData.profit)
          color: row.modelData.profit !== null && row.modelData.profit < 0 ? Color.urgent : root.theme.foreground
          font.bold: row.modelData.profit !== null
        }
      }
    }

    ViewText {
      width: parent.width
      theme: root.theme
      size: "caption"
      tone: "secondary"
      text: "Ganancia esperada por parcela y ciclo. Estimado = datos del juego, aproximado."
      wrapMode: Text.WordWrap
    }
  }
}
