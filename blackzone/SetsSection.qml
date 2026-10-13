import QtQuick
import qs.Commons
import qs.Ui
import "../components"

// Collapsed "Mis sets (n)" section: the list of sets with their editor and
// the field to create a new one.
Column {
  id: root

  required property ViewStyle theme
  required property DeleteConfirm confirm
  required property PieceForm form
  property Item catcher: null
  property bool open: false
  // [{ id, name, pieces }]
  property var sets: []
  // Blackzone.totals(...).bySet
  property var totals: ({})
  // The set whose editor is open ("" = none).
  property string editSetId: ""
  // Error line shown here ("" hides it).
  property string errorText: ""
  property alias newName: newSetRow.text
  // Set by the open editor while one of its fields or dropdowns is in use.
  property bool editorBusy: false
  readonly property bool editing: newSetRow.editing || root.editorBusy

  signal toggled()
  signal createRequested()
  signal editToggled(string setId)
  signal diedRequested(string setId)
  signal renameRequested(string name)
  signal pieceRemoveRequested(int index)
  signal pieceAddRequested(string quantityText)
  signal setRemoveRequested(string setId)

  function focusNewName() { newSetRow.focusField() }

  spacing: root.theme.gap

  PanelSeparator { foreground: root.theme.foreground }

  SectionToggle {
    width: parent.width
    theme: root.theme
    title: "Mis sets (" + root.sets.length + ")"
    open: root.open
    onToggled: root.toggled()
  }

  Column {
    visible: root.open
    width: parent.width
    spacing: root.theme.gap

    ViewText {
      visible: root.sets.length === 0
      width: parent.width
      theme: root.theme
      tone: "secondary"
      text: "Sin sets. Crea uno abajo y agrégale piezas."
    }

    Repeater {
      model: root.sets

      SetCard {
        id: setRow
        required property var modelData
        width: parent.width
        theme: root.theme
        confirm: root.confirm
        form: root.form
        catcher: root.catcher
        busySink: root
        set: setRow.modelData
        total: root.totals[setRow.modelData.id]
        isEditing: root.editSetId === setRow.modelData.id
        onEditToggled: root.editToggled(setRow.modelData.id)
        onDiedRequested: root.diedRequested(setRow.modelData.id)
        onRenameRequested: function(name) { root.renameRequested(name) }
        onPieceRemoveRequested: function(index) { root.pieceRemoveRequested(index) }
        onPieceAddRequested: function(quantityText) { root.pieceAddRequested(quantityText) }
        onSetRemoveRequested: root.setRemoveRequested(setRow.modelData.id)
      }
    }

    FieldRow {
      id: newSetRow
      width: parent.width
      theme: root.theme
      catcher: root.catcher
      placeholderText: "Nombre del set nuevo"
      buttonText: "Crear"
      onSubmitted: root.createRequested()
    }

    ViewText {
      width: parent.width
      theme: root.theme
      size: "caption"
      tone: "secondary"
      text: "Borrar un set no borra las muertes ya registradas."
      wrapMode: Text.WordWrap
    }

    ViewText {
      visible: root.errorText !== ""
      width: parent.width
      theme: root.theme
      size: "caption"
      text: root.errorText
      color: Color.urgent
      wrapMode: Text.WordWrap
    }
  }
}
