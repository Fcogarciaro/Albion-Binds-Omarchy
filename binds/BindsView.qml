import QtQuick
import qs.Commons
import qs.Ui
import "Binds.js" as Binds

// "Atajos" tab: master switch, bind list, add form and backup section.
// State and persistence stay in the bar widget (`owner`, Panel.qml).
Column {
  id: view

  required property var owner
  // Item that takes focus back when a text field is dismissed with Esc.
  property Item catcher: null

  readonly property bool editing: customTriggerField.activeFocus || comboField.activeFocus || dropdown.popupOpen

  spacing: Style.space(14)

  function addBind() {
    var trigger = Binds.normalizeTrigger(owner.newTrigger === "custom" ? customTriggerField.text : owner.newTrigger)
    var combo = Binds.parseCombo(comboField.text)
    if (!trigger) { owner.errorText = "Botón o tecla no válido (ej. mouse:275, F5)."; return }
    if (!combo) { owner.errorText = "Atajo no válido (ej. SHIFT+N, CTRL+ALT+1)."; return }
    if (owner.binds.some(function(b) { return b.trigger === trigger })) {
      owner.errorText = Binds.triggerLabel(trigger) + " ya tiene un atajo."
      return
    }

    owner.errorText = ""
    comboField.text = ""
    customTriggerField.text = ""
    owner.save({ binds: owner.binds.concat([{ trigger: trigger, combo: combo.text, enabled: true }]) })
  }

    // ---------- Hero ----------
    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, masterSwitch.implicitHeight)

      Text {
        id: heroIcon
        textFormat: Text.PlainText
        text: owner.swordIcon
        color: owner.bar.foreground
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.display
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: heroLabels
        anchors.left: heroIcon.right
        anchors.leftMargin: Style.space(14)
        anchors.right: masterSwitch.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          text: "Albion Companion"
          color: owner.bar.foreground
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          text: (owner.masterEnabled ? "Activo · solo en Albion" : "En pausa").toUpperCase()
          color: Qt.darker(owner.bar.foreground, 1.4)
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
          elide: Text.ElideRight
          width: parent.width
        }
      }

      ToggleSwitch {
        id: masterSwitch
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: owner.masterEnabled
        foreground: owner.bar.foreground
        onToggled: owner.save({ enabled: !owner.masterEnabled })
      }
    }

    PanelSeparator { foreground: owner.bar.foreground }

    // ---------- Current binds ----------
    Column {
      width: parent.width
      spacing: Style.space(8)

      PanelSectionHeader {
        text: "ATAJOS"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Text {
        visible: owner.binds.length === 0
        text: "Sin atajos. Agrega uno abajo."
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: owner.binds

        Item {
          id: bindRow
          required property var modelData
          required property int index
          width: parent.width
          implicitHeight: Math.max(bindLabels.implicitHeight, bindSwitch.implicitHeight, removeButton.implicitHeight)
          opacity: modelData.enabled && owner.masterEnabled ? 1 : 0.5

          Column {
            id: bindLabels
            anchors.left: parent.left
            anchors.right: bindSwitch.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: Binds.triggerLabel(bindRow.modelData.trigger) + "  →  " + bindRow.modelData.combo
              color: owner.bar.foreground
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: bindRow.modelData.trigger
              color: owner.bar.foreground
              opacity: 0.6
              font.family: owner.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: bindSwitch
            anchors.right: removeButton.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            checked: bindRow.modelData.enabled
            foreground: owner.bar.foreground
            onToggled: owner.toggleBind(bindRow.index)
          }

          PanelActionButton {
            id: removeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: owner.trashIcon
            tooltipText: "Quitar atajo"
            foreground: owner.bar.foreground
            fontFamily: owner.bar.fontFamily
            onClicked: owner.removeBind(bindRow.index)
          }
        }
      }
    }

    PanelSeparator { foreground: owner.bar.foreground }

    // ---------- Add bind ----------
    Column {
      width: parent.width
      spacing: Style.space(8)

      PanelSectionHeader {
        text: "AGREGAR ATAJO"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Dropdown {
        id: dropdown
        width: parent.width
        label: "Botón"
        value: owner.newTrigger
        options: Binds.TRIGGER_PRESETS
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
        onChanged: function(v) { owner.newTrigger = v; owner.errorText = "" }
      }

      TextField {
        id: customTriggerField
        visible: owner.newTrigger === "custom"
        width: parent.width
        placeholderText: "Tecla o botón de Hyprland (ej. F5, mouse:277)"
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.body
        foreground: owner.bar.foreground
        onAccepted: comboField.forceActiveFocus()
        Keys.onEscapePressed: view.catcher.forceActiveFocus()
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        TextField {
          id: comboField
          width: parent.width - addButton.width - parent.spacing
          placeholderText: "Atajo en Albion (ej. SHIFT+N)"
          font.family: owner.bar.fontFamily
          font.pixelSize: Style.font.body
          foreground: owner.bar.foreground
          onAccepted: view.addBind()
          Keys.onEscapePressed: view.catcher.forceActiveFocus()
        }

        Button {
          id: addButton
          text: "Agregar"
          anchors.verticalCenter: comboField.verticalCenter
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: view.addBind()
        }
      }

      Text {
        visible: owner.errorText !== ""
        width: parent.width
        text: owner.errorText
        color: Color.urgent
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    PanelSeparator { foreground: owner.bar.foreground }

    // ---------- Backup ----------
    Column {
      width: parent.width
      spacing: Style.space(8)

      PanelSectionHeader {
        text: "RESPALDO"
        foreground: owner.bar.foreground
        fontFamily: owner.bar.fontFamily
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "~/albion-companion.json"
        color: owner.bar.foreground
        opacity: 0.6
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Row {
        spacing: Style.space(6)

        Button {
          text: "Exportar"
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: owner.exportBackup()
        }

        Button {
          text: "Importar"
          foreground: owner.bar.foreground
          fontFamily: owner.bar.fontFamily
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: owner.importBackup()
        }
      }

      Text {
        visible: owner.backupText !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: owner.backupText
        color: owner.backupFailed ? Color.urgent : owner.bar.foreground
        opacity: owner.backupFailed ? 1 : 0.7
        font.family: owner.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
}
