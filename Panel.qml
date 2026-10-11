import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "binds/Binds.js" as Binds
import "backup/Backup.js" as Backup

Panel {
  id: root
  moduleName: "fcogarcia.albion-binds"

  readonly property string swordIcon: String.fromCodePoint(0xF04E5)
  readonly property string trashIcon: String.fromCodePoint(0xF01B4)

  readonly property bool masterEnabled: setting("enabled", true) !== false
  readonly property var binds: Binds.sanitizeBinds(setting("binds", Binds.DEFAULT_BINDS))
  readonly property int activeCount: binds.filter(function(b) { return b.enabled }).length

  property string newTrigger: "mouse:275"
  property string errorText: ""
  property string pendingLua: ""
  property string backupPath: Quickshell.env("HOME") + "/albion-binds.json"
  property string backupText: ""
  property bool backupFailed: false
  property string backupAction: ""
  readonly property bool editing: customTriggerField.activeFocus || comboField.activeFocus || dropdown.popupOpen

  function save(changes) {
    root.settings = Object.assign({}, root.settings, changes)
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, root.settings)
    applyToHyprland()
  }

  function applyToHyprland() {
    pendingLua = Binds.generateLua(root.binds, root.masterEnabled)
    if (applyProc.running) return
    runApply()
  }

  function runApply() {
    var script = decodeURIComponent(String(Qt.resolvedUrl("binds/apply.sh")).replace(/^file:\/\//, ""))
    applyProc.command = ["bash", script, pendingLua]
    pendingLua = ""
    applyProc.running = true
  }

  function addBind() {
    var trigger = Binds.normalizeTrigger(newTrigger === "custom" ? customTriggerField.text : newTrigger)
    var combo = Binds.parseCombo(comboField.text)
    if (!trigger) { errorText = "Botón o tecla no válido (ej. mouse:275, F5)."; return }
    if (!combo) { errorText = "Atajo no válido (ej. SHIFT+N, CTRL+ALT+1)."; return }
    if (binds.some(function(b) { return b.trigger === trigger })) {
      errorText = Binds.triggerLabel(trigger) + " ya tiene un atajo."
      return
    }

    errorText = ""
    comboField.text = ""
    customTriggerField.text = ""
    save({ binds: binds.concat([{ trigger: trigger, combo: combo.text, enabled: true }]) })
  }

  function removeBind(index) {
    var next = binds.slice()
    next.splice(index, 1)
    save({ binds: next })
  }

  function toggleBind(index) {
    var next = binds.map(function(b, i) {
      return i === index ? { trigger: b.trigger, combo: b.combo, enabled: !b.enabled } : b
    })
    save({ binds: next })
  }

  function setBackupStatus(text, failed) {
    backupText = text
    backupFailed = failed
  }

  function exportBackup() {
    setBackupStatus("", false)
    backupAction = "export"
    backupFile.setText(Backup.exportBinds(root.binds, root.masterEnabled, Binds.sanitizeBinds))
  }

  function importBackup() {
    setBackupStatus("", false)
    backupAction = "import"
    backupFile.reload()
  }

  function finishImport(text) {
    var result = Backup.parseImport(text, Binds.sanitizeBinds)
    if (!result.ok) { setBackupStatus(result.error, true); return }
    save({ binds: result.binds, enabled: result.enabled })
    setBackupStatus("Importados " + result.binds.length + " atajos."
      + (result.skipped > 0 ? " (" + result.skipped + " ignorados)" : ""), false)
  }

  Component.onCompleted: applyToHyprland()

  // Loading is also triggered once when the path is set; backupAction keeps
  // that initial load from being treated as an import.
  FileView {
    id: backupFile
    path: root.backupPath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.backupAction !== "import") return
      root.backupAction = ""
      root.finishImport(text())
    }
    onLoadFailed: function(error) {
      if (root.backupAction !== "import") return
      root.backupAction = ""
      root.setBackupStatus("No encontré ~/albion-binds.json.", true)
    }
    onSaved: {
      if (root.backupAction !== "export") return
      root.backupAction = ""
      root.setBackupStatus("Exportado a ~/albion-binds.json (" + root.binds.length + " atajos).", false)
    }
    onSaveFailed: function(error) {
      if (root.backupAction !== "export") return
      root.backupAction = ""
      root.setBackupStatus("No pude guardar ~/albion-binds.json.", true)
    }
  }

  Process {
    id: applyProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") root.errorText = "Hyprland: " + text.trim()
    }
    onExited: if (root.pendingLua !== "") root.runApply()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.swordIcon
    opacity: root.masterEnabled && root.activeCount > 0 ? 1 : 0.4
    tooltipText: root.masterEnabled
      ? "Albion Binds: " + root.activeCount + " atajo(s) activo(s)"
      : "Albion Binds: en pausa"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.save({ enabled: !root.masterEnabled })
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, masterSwitch.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.swordIcon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
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
              text: "Albion Binds"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: (root.masterEnabled ? "Activo · solo en Albion" : "En pausa").toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
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
            checked: root.masterEnabled
            foreground: root.bar.foreground
            onToggled: root.save({ enabled: !root.masterEnabled })
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Current binds ----------
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "ATAJOS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Text {
            visible: root.binds.length === 0
            text: "Sin atajos. Agrega uno abajo."
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.binds

            Item {
              id: bindRow
              required property var modelData
              required property int index
              width: parent.width
              implicitHeight: Math.max(bindLabels.implicitHeight, bindSwitch.implicitHeight, removeButton.implicitHeight)
              opacity: modelData.enabled && root.masterEnabled ? 1 : 0.5

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
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: bindRow.modelData.trigger
                  color: root.bar.foreground
                  opacity: 0.6
                  font.family: root.bar.fontFamily
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
                foreground: root.bar.foreground
                onToggled: root.toggleBind(bindRow.index)
              }

              PanelActionButton {
                id: removeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.trashIcon
                tooltipText: "Quitar atajo"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.removeBind(bindRow.index)
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Add bind ----------
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "AGREGAR ATAJO"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Dropdown {
            id: dropdown
            width: parent.width
            label: "Botón"
            value: root.newTrigger
            options: Binds.TRIGGER_PRESETS
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onChanged: function(v) { root.newTrigger = v; root.errorText = "" }
          }

          TextField {
            id: customTriggerField
            visible: root.newTrigger === "custom"
            width: parent.width
            placeholderText: "Tecla o botón de Hyprland (ej. F5, mouse:277)"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            foreground: root.bar.foreground
            onAccepted: comboField.forceActiveFocus()
            Keys.onEscapePressed: keyCatcher.forceActiveFocus()
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: comboField
              width: parent.width - addButton.width - parent.spacing
              placeholderText: "Atajo en Albion (ej. SHIFT+N)"
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              foreground: root.bar.foreground
              onAccepted: root.addBind()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }

            Button {
              id: addButton
              text: "Agregar"
              anchors.verticalCenter: comboField.verticalCenter
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.addBind()
            }
          }

          Text {
            visible: root.errorText !== ""
            width: parent.width
            text: root.errorText
            color: Color.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Backup ----------
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "RESPALDO"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "~/albion-binds.json"
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Row {
            spacing: Style.space(6)

            Button {
              text: "Exportar"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.exportBackup()
            }

            Button {
              text: "Importar"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.importBackup()
            }
          }

          Text {
            visible: root.backupText !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: root.backupText
            color: root.backupFailed ? Color.urgent : root.bar.foreground
            opacity: root.backupFailed ? 1 : 0.7
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
