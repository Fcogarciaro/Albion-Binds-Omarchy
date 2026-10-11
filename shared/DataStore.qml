import QtQuick
import Quickshell
import Quickshell.Io
import "Storage.js" as Store
import "../farm/Farm.js" as Farm

// Loads ~/.local/share/albion-companion/data.json on start and saves it on
// demand. The file is never created until saveData() is called.
Item {
  id: root
  visible: false

  readonly property string dir: Quickshell.env("HOME") + "/.local/share/albion-companion"
  readonly property string path: dir + "/data.json"

  // Not named `data`: that would shadow Item's default property and swallow
  // the FileView/Process children.
  property var document: Store.defaultData()
  property bool loaded: false
  property bool dirReady: false
  property string error: ""

  // FileView is not documented to create parent directories, so mkdir -p
  // runs first (same approach as plugins/notifications/Service.qml).
  // Saves the current document. The directory is created once per session;
  // a save requested while mkdir runs is written when it finishes.
  function saveData() {
    if (dirReady) file.setText(Store.serializeData(root.document))
    else if (!mkdirProc.running) mkdirProc.running = true
  }

  FileView {
    id: file
    path: root.path
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var result = Store.parseData(text(), Farm.sanitizeFarm)
      if (result.ok) {
        root.document = result.data
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
      if (exitCode === 0) {
        root.dirReady = true
        file.setText(Store.serializeData(root.document))
      } else root.error = "No pude crear la carpeta de datos."
    }
  }
}
