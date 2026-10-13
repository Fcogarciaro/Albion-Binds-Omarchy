import QtQuick
import "Farm.js" as Farm
import "../components"

// Collapsed "Impuesto de venta" section. The field follows `taxRate` (also
// when the data file finishes loading) unless it is being edited.
Column {
  id: root

  required property ViewStyle theme
  property Item catcher: null
  property bool open: false
  property real taxRate: 0.065
  property alias text: rateRow.text
  readonly property bool editing: rateRow.editing

  signal toggled()
  signal saveRequested()

  spacing: root.theme.gap

  onTaxRateChanged: if (!rateRow.editing) rateRow.text = Farm.formatPercent(root.taxRate)
  Component.onCompleted: rateRow.text = Farm.formatPercent(root.taxRate)

  SectionToggle {
    width: parent.width
    theme: root.theme
    title: "Impuesto de venta"
    open: root.open
    onToggled: root.toggled()
  }

  Column {
    visible: root.open
    width: parent.width
    spacing: root.theme.gap

    FieldRow {
      id: rateRow
      width: parent.width
      theme: root.theme
      catcher: root.catcher
      placeholderText: "6.5"
      buttonText: "Guardar"
      onSubmitted: root.saveRequested()
    }

    ViewText {
      width: parent.width
      theme: root.theme
      size: "caption"
      tone: "secondary"
      text: "6.5 % = 4 % de impuesto con premium + 2.5 % de orden de venta."
      wrapMode: Text.WordWrap
    }
  }
}
