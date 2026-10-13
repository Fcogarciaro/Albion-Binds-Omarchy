import QtQuick
import qs.Ui

// A label with a switch at the right. The switch does not flip on its own:
// the owner updates `checked` and reacts to `toggled`.
Item {
  id: root

  required property ViewStyle theme
  property string text: ""
  property bool checked: false

  signal toggled()

  implicitHeight: Math.max(label.implicitHeight, toggle.implicitHeight)

  ViewText {
    id: label
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    theme: root.theme
    text: root.text
  }

  ToggleSwitch {
    id: toggle
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    checked: root.checked
    foreground: root.theme.foreground
    onToggled: root.toggled()
  }
}
