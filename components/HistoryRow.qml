import QtQuick
import qs.Commons

// One history line: label, value and a two-tap delete button.
Item {
  id: root

  required property ViewStyle theme
  property string label: ""
  property string valueText: ""
  property bool urgent: false
  property string deleteText: "Eliminar"

  signal deleteRequested()

  implicitHeight: Math.max(labelText.implicitHeight, valueLabel.implicitHeight, deleteButton.implicitHeight)

  ViewText {
    id: labelText
    anchors.left: parent.left
    anchors.right: valueLabel.left
    anchors.rightMargin: root.theme.gap
    anchors.verticalCenter: parent.verticalCenter
    theme: root.theme
    text: root.label
    elide: Text.ElideRight
  }

  ViewText {
    id: valueLabel
    anchors.right: deleteButton.left
    anchors.rightMargin: root.theme.gap
    anchors.verticalCenter: parent.verticalCenter
    theme: root.theme
    text: root.valueText
    color: root.urgent ? Color.urgent : root.theme.foreground
    font.bold: true
  }

  ViewButton {
    id: deleteButton
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    theme: root.theme
    role: "compact"
    text: root.deleteText
    onClicked: root.deleteRequested()
  }
}
