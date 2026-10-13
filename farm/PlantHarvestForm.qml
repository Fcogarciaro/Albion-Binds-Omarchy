import QtQuick
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "Prices.js" as Prices
import "../components"

// Compose card of a plot: plant (crop, seeds, seed price) or harvest (crops,
// returned seeds, crop price), with the market price prefill. The view owns
// the logic; this card holds the fields and reports through signals.
ComposeCard {
  id: root

  property Item catcher: null
  // "plant" | "harvest"
  property string mode: "plant"
  property var cropOptions: []
  property string crop: ""
  // Harvest only: what was planted.
  property string cycleInfo: ""
  property string city: ""
  property string priceText: ""
  // Harvest only: estimated profit (number) or null.
  property var preview: null

  property alias seedsText: seedsField.text
  property alias seedPriceText: seedPriceField.text
  property alias harvestedText: harvestedField.text
  property alias returnedText: returnedField.text
  property alias cropPriceText: cropPriceField.text

  readonly property bool editing: seedsField.activeFocus || seedPriceField.activeFocus || harvestedField.activeFocus
    || returnedField.activeFocus || cropPriceField.activeFocus || cropDropdown.popupOpen || cityDropdown.popupOpen

  signal cropPicked(string value)
  signal cityPicked(string value)
  signal priceRequested()
  signal plantRequested()
  signal harvestRequested()

  function clear() {
    seedsField.text = ""
    seedPriceField.text = ""
    harvestedField.text = ""
    returnedField.text = ""
    cropPriceField.text = ""
  }

  function focusFirst() {
    if (root.mode === "plant") seedsField.forceActiveFocus()
    else harvestedField.forceActiveFocus()
  }

  Dropdown {
    id: cropDropdown
    visible: root.mode === "plant"
    width: parent.width
    label: "Cultivo"
    value: root.crop
    options: root.cropOptions
    foreground: root.theme.foreground
    fontFamily: root.theme.fontFamily
    onChanged: function(v) { root.cropPicked(v) }
  }

  ViewText {
    visible: root.mode === "harvest" && root.cycleInfo !== ""
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "label"
    text: root.cycleInfo
    wrapMode: Text.WordWrap
  }

  ViewField {
    id: seedsField
    visible: root.mode === "plant"
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Semillas plantadas"
    onAccepted: seedPriceField.forceActiveFocus()
  }

  ViewField {
    id: seedPriceField
    visible: root.mode === "plant"
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Precio por semilla (ej. 450k)"
    onAccepted: root.plantRequested()
  }

  ViewField {
    id: harvestedField
    visible: root.mode === "harvest"
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Cultivos cosechados"
    onAccepted: returnedField.forceActiveFocus()
  }

  ViewField {
    id: returnedField
    visible: root.mode === "harvest"
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Semillas devueltas"
    onAccepted: cropPriceField.forceActiveFocus()
  }

  ViewField {
    id: cropPriceField
    visible: root.mode === "harvest"
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Precio por cultivo (ej. 1.2k)"
    onAccepted: root.harvestRequested()
  }

  Row {
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
      text: "Precio de mercado"
      onClicked: root.priceRequested()
    }
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

  ViewText {
    visible: root.preview !== null
    width: parent.width
    theme: root.theme
    text: root.preview !== null ? "Ganancia estimada: " + Farm.signed(root.preview) + " plata" : ""
    color: root.preview !== null && root.preview < 0 ? Color.urgent : root.theme.foreground
    font.bold: true
  }

  ViewButton {
    theme: root.theme
    text: root.mode === "plant" ? "Guardar siembra" : "Guardar cosecha"
    onClicked: root.mode === "plant" ? root.plantRequested() : root.harvestRequested()
  }
}
