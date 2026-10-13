import QtQuick

// Two-tap delete: the first tap arms a control (by key), the second one runs
// its action. An armed control disarms itself if the second tap never comes.
Item {
  id: root

  // Key of the armed control ("" = none).
  property string key: ""
  property int timeout: 4000

  visible: false

  function label(controlKey, idle) { return root.key === controlKey ? "¿Seguro?" : idle }

  function ask(controlKey, action) {
    if (root.key !== controlKey) {
      root.key = controlKey
      timer.restart()
      return
    }
    root.reset()
    action()
  }

  function reset() {
    root.key = ""
    timer.stop()
  }

  Timer {
    id: timer
    interval: root.timeout
    onTriggered: root.key = ""
  }
}
