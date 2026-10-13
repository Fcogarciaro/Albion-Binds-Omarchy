import QtQuick
import qs.Ui
import "../farm/Prices.js" as Prices
import "../components"

// Compose card for a death: pick the set (tap chips), market prices for its
// pieces and an editable total. The view owns the logic and the price fetch.
ComposeCard {
  id: root

  property Item catcher: null
  // [{ id, name }]
  property var sets: []
  property string selectedSetId: ""
  property string city: ""
  property string server: ""
  property string priceText: ""
  // One row per piece of the selected set: [{ label, priceText, known }]
  property var rows: []
  property alias valueText: valueField.text
  readonly property bool hasSets: root.sets.length > 0
  readonly property bool editing: valueField.activeFocus || cityDropdown.popupOpen || serverDropdown.popupOpen

  signal createSetRequested()
  signal setPicked(string id)
  signal cityPicked(string value)
  signal serverPicked(string value)
  signal refreshRequested()
  // The total was typed by hand.
  signal valueEdited()
  signal saveRequested()

  title: "Muerte"

  function focusFirst() { valueField.forceActiveFocus() }

  ViewText {
    visible: !root.hasSets
    width: parent.width
    theme: root.theme
    tone: "secondary"
    text: "Crea un set con piezas primero."
  }

  ViewButton {
    visible: !root.hasSets
    theme: root.theme
    text: "Crear un set"
    onClicked: root.createSetRequested()
  }

  Flow {
    visible: root.hasSets
    width: parent.width
    spacing: root.theme.gap

    Repeater {
      model: root.sets

      ViewButton {
        id: setChip
        required property var modelData
        theme: root.theme
        text: setChip.modelData.name
        selected: root.selectedSetId === setChip.modelData.id
        onClicked: root.setPicked(setChip.modelData.id)
      }
    }
  }

  Row {
    visible: root.hasSets
    width: parent.width
    spacing: root.theme.gap

    Dropdown {
      id: cityDropdown
      width: parent.width - priceButton.width - parent.spacing
      label: "Ciudad"
      value: root.city
      options: Prices.CITIES
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
      onChanged: function(v) { root.cityPicked(v) }
    }

    ViewButton {
      id: priceButton
      anchors.verticalCenter: cityDropdown.verticalCenter
      theme: root.theme
      text: "Actualizar precios"
      onClicked: root.refreshRequested()
    }
  }

  Dropdown {
    id: serverDropdown
    visible: root.hasSets
    width: parent.width
    label: "Servidor"
    value: root.server
    options: Prices.SERVER_OPTIONS
    foreground: root.theme.foreground
    fontFamily: root.theme.fontFamily
    onChanged: function(v) { root.serverPicked(v) }
  }

  ViewText {
    visible: root.priceText !== ""
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "label"
    text: root.priceText
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.rows

    Item {
      id: piece
      required property var modelData
      width: parent.width
      implicitHeight: Math.max(pieceText.implicitHeight, pricePiece.implicitHeight)

      ViewText {
        id: pieceText
        anchors.left: parent.left
        anchors.right: pricePiece.left
        anchors.rightMargin: root.theme.gap
        anchors.verticalCenter: parent.verticalCenter
        theme: root.theme
        text: piece.modelData.label
        elide: Text.ElideRight
      }

      ViewText {
        id: pricePiece
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: root.theme
        tone: piece.modelData.known ? "normal" : "secondary"
        text: piece.modelData.priceText
      }
    }
  }

  ViewText {
    visible: root.hasSets
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "label"
    text: "Total perdido (editable)"
  }

  ViewField {
    id: valueField
    visible: root.hasSets
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Valor perdido (ej. 450k)"
    onTextEdited: root.valueEdited()
    onAccepted: root.saveRequested()
  }

  ViewButton {
    visible: root.hasSets
    theme: root.theme
    text: "Guardar muerte"
    onClicked: root.saveRequested()
  }
}
