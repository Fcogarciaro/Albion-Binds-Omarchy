import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "binds/Binds.js" as Binds
import "backup/Backup.js" as Backup
import "shared"
import "binds"
import "farm"
import "blackzone"

Panel {
  id: root
  moduleName: "fcogarcia.albion-companion"

  readonly property string swordIcon: String.fromCodePoint(0xF04E5)
  readonly property string trashIcon: String.fromCodePoint(0xF01B4)

  readonly property bool masterEnabled: setting("enabled", true) !== false
  readonly property var binds: Binds.sanitizeBinds(setting("binds", Binds.DEFAULT_BINDS))
  readonly property int activeCount: binds.filter(function(b) { return b.enabled }).length

  property string newTrigger: "mouse:275"
  property string errorText: ""
  property string pendingLua: ""
  property string backupPath: Quickshell.env("HOME") + "/albion-companion.json"
  // Backups written by the old Albion Binds plugin; used only when importing.
  property string legacyBackupPath: Quickshell.env("HOME") + "/albion-binds.json"
  property string backupText: ""
  property bool backupFailed: false
  property string backupAction: ""
  property string currentTab: "binds"
  readonly property bool editing: (currentTab === "binds" && bindsView.editing) || (currentTab === "farm" && farmView.editing)

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

  function finishImport(text, fileLabel) {
    var result = Backup.parseImport(text, Binds.sanitizeBinds)
    if (!result.ok) { setBackupStatus(result.error, true); return }
    save({ binds: result.binds, enabled: result.enabled })
    setBackupStatus("Importados " + result.binds.length + " atajos desde " + fileLabel + "."
      + (result.skipped > 0 ? " (" + result.skipped + " ignorados)" : ""), false)
  }

  // Tracker data (farm log, black zone). Tabs read and save it through `store`.
  DataStore { id: dataStore }
  readonly property var store: dataStore

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
      root.finishImport(text(), "~/albion-companion.json")
    }
    onLoadFailed: function(error) {
      if (root.backupAction !== "import") return
      // New file missing: fall back to the backup of the old plugin.
      legacyBackupFile.reload()
    }
    onSaved: {
      if (root.backupAction !== "export") return
      root.backupAction = ""
      root.setBackupStatus("Exportado a ~/albion-companion.json (" + root.binds.length + " atajos).", false)
    }
    onSaveFailed: function(error) {
      if (root.backupAction !== "export") return
      root.backupAction = ""
      root.setBackupStatus("No pude guardar ~/albion-companion.json.", true)
    }
  }

  FileView {
    id: legacyBackupFile
    path: root.legacyBackupPath
    printErrors: false
    onLoaded: {
      if (root.backupAction !== "import") return
      root.backupAction = ""
      root.finishImport(text(), "~/albion-binds.json")
    }
    onLoadFailed: function(error) {
      if (root.backupAction !== "import") return
      root.backupAction = ""
      root.setBackupStatus("No encontré ~/albion-companion.json ni ~/albion-binds.json.", true)
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
      ? "Albion Companion: " + root.activeCount + " atajo(s) activo(s)"
      : "Albion Companion: en pausa"
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

        // The selected tab lives in memory only.
        ButtonGroup {
          id: tabs
          options: [
            { value: "binds", label: "Atajos" },
            { value: "farm", label: "Cultivos" },
            { value: "blackzone", label: "Zona negra" }
          ]
          value: root.currentTab
          focusable: false
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          fontSize: Style.font.bodySmall
          onChanged: function(v) { root.currentTab = v }
        }

        BindsView {
          id: bindsView
          width: parent.width
          visible: root.currentTab === "binds"
          owner: root
          catcher: keyCatcher
        }

        FarmView {
          id: farmView
          width: parent.width
          visible: root.currentTab === "farm"
          owner: root
          catcher: keyCatcher
        }

        BlackzoneView {
          width: parent.width
          visible: root.currentTab === "blackzone"
          owner: root
        }
      }
    }
  }
}
