import QtQuick
import Quickshell
import Quickshell.Io
import "Storage.js" as Store

// Loads ~/.local/share/albion-companion/data.json on start and saves it on
// demand. The file is never created until saveData() is called.
Item {
  id: root
  visible: false

  readonly property string dir: Quickshell.env("HOME") + "/.local/share/albion-companion"
  readonly property string path: dir + "/data.json"

  property var data: Store.defaultData()
  property bool loaded: false
  property string error: ""

  // FileView is not documented to create parent directories, so mkdir -p
  // runs first (same approach as plugins/notifications/Service.qml).
  function saveData() {
    if (mkdirProc.running) return
    mkdirProc.running = true
  }

  FileView {
    id: file
    path: root.path
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var result = Store.parseData(text())
      if (result.ok) {
        root.data = result.data
        root.error = ""
      } else {
        root.error = result.error
      }
      root.loaded = true
    }
    // A missing file is the normal first-run state: keep the defaults.
    onLoadFailed: function(err) { root.loaded = true }
    onSaveFailed: function(err) { root.error = "No pude guardar los datos." }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.dir]
    onExited: function(exitCode) {
      if (exitCode === 0) file.setText(Store.serializeData(root.data))
      else root.error = "No pude crear la carpeta de datos."
    }
  }
}
