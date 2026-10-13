import QtQuick

// A text field with its submit button beside it. Enter in the field and a tap
// on the button both emit `submitted`.
Row {
  id: root

  required property ViewStyle theme
  property Item catcher: null
  property alias text: field.text
  property alias placeholderText: field.placeholderText
  property string buttonText: ""
  readonly property bool editing: field.activeFocus

  signal submitted()

  function focusField() { field.forceActiveFocus() }

  spacing: root.theme.gap

  ViewField {
    id: field
    width: root.width - button.width - root.spacing
    theme: root.theme
    catcher: root.catcher
    onAccepted: root.submitted()
  }

  ViewButton {
    id: button
    anchors.verticalCenter: field.verticalCenter
    text: root.buttonText
    theme: root.theme
    onClicked: root.submitted()
  }
}
