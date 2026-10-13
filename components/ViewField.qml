import QtQuick
import qs.Ui

// Text field in the views' look. Esc hands the focus back to `catcher`.
TextField {
  id: root

  required property ViewStyle theme
  // Item that takes focus back when the field is dismissed with Esc.
  property Item catcher: null

  foreground: root.theme.foreground
  font.family: root.theme.fontFamily
  font.pixelSize: root.theme.fontBody
  Keys.onEscapePressed: if (root.catcher) root.catcher.forceActiveFocus()
}
