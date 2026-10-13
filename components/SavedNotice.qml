import QtQuick

// Brief confirmation after a save: `text` is "" (hidden) until flash() runs.
Item {
  id: root

  property string text: ""
  property int duration: 2000

  visible: false

  function flash() {
    root.text = "Guardado"
    timer.restart()
  }

  Timer {
    id: timer
    interval: root.duration
    onTriggered: root.text = ""
  }
}
