import QtQuick
import "Blackzone.js" as Bz
import "../farm/Farm.js" as Farm
import "../components"

// Compose card for a loot: silver value, tomes of insight per tier, note.
ComposeCard {
  id: root

  property Item catcher: null
  property alias valueText: valueField.text
  property alias noteText: noteField.text
  // Tome counters live inside a Repeater: they push their text here
  // ({ "<tier>": "text" }) and report focus through tomeBusy.
  property var tomeInput: ({})
  property bool tomeBusy: false
  readonly property bool editing: valueField.activeFocus || noteField.activeFocus || root.tomeBusy

  signal saveRequested()
  // The tome fields clear themselves on this.
  signal tomesCleared()

  title: "Botín"

  function setTomeText(tier, text) {
    var next = {}
    for (var k in root.tomeInput) next[k] = root.tomeInput[k]
    next[tier] = text
    root.tomeInput = next
  }

  // Counts typed in the tome fields ({ "<tier>": n }), or null when one is not a whole number.
  function parseTomes() {
    var out = {}
    for (var k in root.tomeInput) {
      var text = String(root.tomeInput[k]).trim()
      if (text === "") continue
      var n = Farm.parseInteger(text)
      if (n === null) return null
      if (n > 0) out[k] = n
    }
    return out
  }

  function clear() {
    root.tomeInput = ({})
    root.tomesCleared()
    valueField.text = ""
    noteField.text = ""
  }

  function focusFirst() { valueField.forceActiveFocus() }

  ViewField {
    id: valueField
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Valor del botín (ej. 1.2m)"
    onAccepted: root.saveRequested()
  }

  ViewText {
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "label"
    text: "Tomos de conocimiento (cantidad por nivel, sin valor en plata)"
    wrapMode: Text.WordWrap
  }

  Flow {
    width: parent.width
    spacing: root.theme.gap

    Repeater {
      model: Bz.TOME_TIERS

      ViewField {
        id: tomeField
        required property var modelData
        width: (parent.width - 3 * root.theme.gap) / 4
        theme: root.theme
        catcher: root.catcher
        placeholderText: "T" + tomeField.modelData.tier
        onTextChanged: root.setTomeText(tomeField.modelData.tier, text)
        onAccepted: root.saveRequested()
        onActiveFocusChanged: root.tomeBusy = activeFocus

        Connections {
          target: root
          function onTomesCleared() { tomeField.text = "" }
        }
      }
    }
  }

  ViewField {
    id: noteField
    width: parent.width
    theme: root.theme
    catcher: root.catcher
    placeholderText: "Nota (opcional)"
    onAccepted: root.saveRequested()
  }

  ViewButton {
    theme: root.theme
    text: "Guardar botín"
    onClicked: root.saveRequested()
  }
}
