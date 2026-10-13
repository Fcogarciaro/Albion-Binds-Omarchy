import QtQuick
import qs.Commons
import qs.Ui
import "Blackzone.js" as Bz
import "../farm/Farm.js" as Farm
import "../components"

// One gear set: name, stats, "Morí con este set" and, while editing, the
// rename field, its pieces and the "Agregar pieza" form.
Column {
  id: root

  required property ViewStyle theme
  required property DeleteConfirm confirm
  required property PieceForm form
  property Item catcher: null
  // Set { id, name, pieces }
  property var set: null
  // Lifetime totals { deaths, lost } or undefined.
  property var total: undefined
  property bool isEditing: false
  // Receives `editorBusy` while this editor is open (see below).
  property QtObject busySink: null
  readonly property string setName: root.set ? root.set.name : ""
  // A field is focused or a dropdown popup is open in the open editor.
  readonly property bool busy: renameRow.editing || quantityField.activeFocus
    || slotDropdown.popupOpen || baseDropdown.popupOpen || tierDropdown.popupOpen
    || enchantDropdown.popupOpen || qualityDropdown.popupOpen

  signal editToggled()
  signal diedRequested()
  signal renameRequested(string name)
  signal pieceRemoveRequested(int index)
  signal pieceAddRequested(string quantityText)
  signal setRemoveRequested()

  spacing: root.theme.gap

  // The rename field follows the set's name: it is filled when the card is
  // created (the sets list rebuilds its cards after every change) and when the
  // name changes, unless the user is typing in it.
  onSetNameChanged: if (!renameRow.editing) renameRow.text = root.setName
  Component.onCompleted: renameRow.text = root.setName

  // Fields and dropdowns of the editor report through `busy` while it is open.
  Binding {
    target: root.busySink
    property: "editorBusy"
    when: root.isEditing && root.busySink !== null
    value: root.busy
  }

  Item {
    width: parent.width
    implicitHeight: Math.max(labels.implicitHeight, editButton.implicitHeight)

    Column {
      id: labels
      anchors.left: parent.left
      anchors.right: editButton.left
      anchors.rightMargin: root.theme.gap
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      ViewText {
        width: parent.width
        theme: root.theme
        size: "body"
        text: root.setName
        font.bold: true
        elide: Text.ElideRight
      }

      ViewText {
        width: parent.width
        theme: root.theme
        size: "caption"
        tone: "label"
        text: (root.set ? root.set.pieces.length : 0) + " pieza(s)"
          + (root.total ? " · " + root.total.deaths + " muerte(s), -" + Farm.formatSilver(root.total.lost) : "")
        elide: Text.ElideRight
      }

      ViewButton {
        visible: root.set !== null && root.set.pieces.length > 0
        theme: root.theme
        role: "compact"
        text: "Morí con este set"
        onClicked: root.diedRequested()
      }
    }

    ViewButton {
      id: editButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      text: root.isEditing ? "Cerrar" : "Editar"
      onClicked: root.editToggled()
    }
  }

  Column {
    visible: root.isEditing
    width: parent.width
    spacing: root.theme.gap

    FieldRow {
      id: renameRow
      width: parent.width
      theme: root.theme
      catcher: root.catcher
      placeholderText: "Nombre del set"
      buttonText: "Renombrar"
      onSubmitted: root.renameRequested(renameRow.text)
    }

    Repeater {
      model: root.set ? root.set.pieces : []

      Item {
        id: pieceRow
        required property var modelData
        required property int index
        width: parent.width
        implicitHeight: Math.max(pieceText.implicitHeight, pieceDelete.implicitHeight)

        ViewText {
          id: pieceText
          anchors.left: parent.left
          anchors.right: pieceDelete.left
          anchors.rightMargin: root.theme.gap
          anchors.verticalCenter: parent.verticalCenter
          theme: root.theme
          text: root.form.pieceLabel(pieceRow.modelData)
          elide: Text.ElideRight
        }

        ViewButton {
          id: pieceDelete
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          theme: root.theme
          role: "compact"
          text: "Quitar"
          onClicked: root.pieceRemoveRequested(pieceRow.index)
        }
      }
    }

    ViewText {
      theme: root.theme
      size: "caption"
      tone: "label"
      text: "Agregar pieza"
      font.bold: true
    }

    Dropdown {
      id: slotDropdown
      width: parent.width
      label: "Ranura"
      value: root.form.slot
      options: Bz.SLOTS
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
      onChanged: function(v) { root.form.setSlot(v) }
    }

    SearchableDropdown {
      id: baseDropdown
      width: parent.width
      label: "Pieza"
      value: root.form.base !== "" ? root.form.base + ":" + root.form.tier : ""
      options: root.form.baseOptions
      placeholderText: "Buscar…"
      emptyText: "Sin resultados"
      triggerLabel: "Elige una pieza"
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
      onChanged: function(v) { root.form.setOption(v) }
    }

    Row {
      width: parent.width
      spacing: root.theme.gap

      Dropdown {
        id: tierDropdown
        width: (parent.width - parent.spacing * (root.form.isConsumable ? 1 : 2)) / (root.form.isConsumable ? 2 : 3)
        label: "Nivel"
        value: String(root.form.tier)
        options: root.form.tierOptions
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
        onChanged: function(v) { root.form.tier = Number(v) }
      }

      Dropdown {
        id: enchantDropdown
        width: tierDropdown.width
        label: "Encantamiento"
        value: String(root.form.enchant)
        options: root.form.enchantOptions
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
        onChanged: function(v) { root.form.enchant = Number(v) }
      }

      Dropdown {
        id: qualityDropdown
        visible: !root.form.isConsumable
        width: tierDropdown.width
        label: "Calidad"
        value: String(root.form.quality)
        options: root.form.qualityOptions
        foreground: root.theme.foreground
        fontFamily: root.theme.fontFamily
        onChanged: function(v) { root.form.quality = Number(v) }
      }
    }

    ViewField {
      id: quantityField
      visible: root.form.isConsumable
      width: parent.width
      theme: root.theme
      catcher: root.catcher
      placeholderText: "Cantidad (1 si lo dejas vacío)"
      onAccepted: root.pieceAddRequested(quantityField.text)

      Connections {
        target: root.form
        function onCleared() { quantityField.text = "" }
      }
    }

    ViewButton {
      theme: root.theme
      text: "Agregar pieza"
      onClicked: root.pieceAddRequested(quantityField.text)
    }

    ViewButton {
      theme: root.theme
      role: "compact"
      text: root.confirm.label("set:" + (root.set ? root.set.id : ""), "Eliminar set")
      onClicked: root.confirm.ask("set:" + root.set.id, function() { root.setRemoveRequested() })
    }
  }
}
