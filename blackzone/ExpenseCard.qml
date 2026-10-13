import QtQuick
import "../components"

// Compose card for an expense: silver value and a note.
ComposeCard {
  id: root

  property Item catcher: null
  property alias valueText: valueField.text
  property alias noteText: noteField.text
  readonly property bool editing: valueField.activeFocus || noteField.activeFocus

  signal saveRequested()

  title: "Gasto"

  function clear() {
    valueField.text = ""
    noteField.text = ""
  }

  function focusFirst() { valueField.forceActiveFocus() }

  ViewField {
    id: valueField
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Gasto (ej. 12k)"
    onAccepted: root.saveRequested()
  }

  ViewField {
    id: noteField
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Portal SAFE"
    onAccepted: root.saveRequested()
  }

  ViewButton {
    theme: root.theme
    text: "Guardar gasto"
    onClicked: root.saveRequested()
  }
}
