pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Storage.js" as Store
import "../farm/Farm.js" as Farm
import "../blackzone/Blackzone.js" as Blackzone

// Loads ~/.local/share/albion-companion/data.json on start and saves it on
// demand. The file is never created until saveData() is called.
//
// Singleton (see qmldir): the bar panel (Panel.qml) and the large window
// (Window.qml) live in the same shell process and must edit ONE document.
// With a store each, a surface that started before the file existed never
// watched it and kept a stale copy whose next save dropped the other's data.
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

  // Text of the last write we issued. A change notification that reads it back
  // is our own atomic write (rename) echoing, not an external edit.
  property string lastWritten: ""
  // Writes issued and not yet reported as saved/failed. While > 0, reloads
  // are deferred so a stale read can never overwrite newer in-memory edits.
  property int pendingWrites: 0
  property bool reloadPending: false
  property bool reloadError: false
  // False while the watcher could not attach (the file did not exist when it
  // started): an inotify watch needs the file, so nothing would ever notify.
  property bool watchArmed: false

  // FileView is not documented to create parent directories, so mkdir -p
  // runs first (same approach as plugins/notifications/Service.qml).
  // Saves the current document. The directory is created once per session;
  // a save requested while mkdir runs is written when it finishes.
  function saveData() {
    if (dirReady) writeNow()
    else if (!mkdirProc.running) {
      pendingWrites++
      mkdirProc.running = true
    }
  }

  function writeNow() {
    var text = Store.serializeData(root.document)
    root.lastWritten = text
    root.pendingWrites++
    file.setText(text)
  }

  function writeDone() {
    root.pendingWrites = Math.max(0, root.pendingWrites - 1)
    if (root.pendingWrites === 0 && root.reloadPending) {
      root.reloadPending = false
      file.reload()
    }
  }

  // Verified with Quickshell on this machine: watchChanges keeps firing
  // fileChanged after rename-over (Syncthing), delete and re-create.
  function applyReload(text) {
    var out = Store.reloadOutcome(text, root.lastWritten, root.document, Farm.sanitizeFarm, Blackzone.sanitizeBlackzone)
    if (out.action === "apply") {
      root.document = out.data
      root.error = ""
      root.reloadError = false
    } else if (out.action === "error") {
      root.error = out.error
      root.reloadError = true
    } else if (root.reloadError) {
      root.error = ""
      root.reloadError = false
    }
  }

  FileView {
    id: file
    path: root.path
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.watchArmed = true
      if (root.loaded && root.pendingWrites > 0) {
        root.reloadPending = true
        return
      }
      if (root.loaded) {
        root.applyReload(text())
      } else {
        var result = Store.parseData(text(), Farm.sanitizeFarm, Blackzone.sanitizeBlackzone)
        if (result.ok) {
          root.document = result.data
          root.error = ""
        } else {
          root.error = result.error
        }
        root.loaded = true
      }
    }
    // A missing file is the normal first-run state: keep the defaults. A file
    // deleted later keeps the in-memory document too.
    onLoadFailed: function(err) { root.loaded = true }
    onFileChanged: {
      if (root.pendingWrites > 0) root.reloadPending = true
      else file.reload()
    }
    onSaved: {
      // First save created the file: attach the watcher now so later external
      // edits (sync, another PC) are noticed.
      if (!root.watchArmed) {
        root.watchArmed = true
        file.watchChanges = false
        file.watchChanges = true
      }
      root.writeDone()
    }
    onSaveFailed: function(err) {
      root.error = "No pude guardar los datos."
      root.writeDone()
    }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.dir]
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.dirReady = true
        root.writeNow()
        root.writeDone()
      } else {
        root.error = "No pude crear la carpeta de datos."
        root.writeDone()
      }
    }
  }
}
