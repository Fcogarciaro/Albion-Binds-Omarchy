import QtQuick
import "../components"

// Collapsed "Agregar parcela" section.
Column {
  id: root

  required property ViewStyle theme
  property Item catcher: null
  property bool open: false
  property alias name: nameRow.text
  readonly property bool editing: nameRow.editing

  signal toggled()
  signal addRequested()

  spacing: root.theme.gap

  SectionToggle {
    width: parent.width
    theme: root.theme
    title: "Agregar parcela"
    open: root.open
    onToggled: root.toggled()
  }

  FieldRow {
    id: nameRow
    visible: root.open
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Nombre de la parcela"
    buttonText: "Agregar"
    onSubmitted: root.addRequested()
  }
}
