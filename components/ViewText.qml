import QtQuick

// Text in the views' look. `size` picks the font role, `tone` the opacity:
// "label" for captions and labels, "secondary" for hints and empty states.
Text {
  id: root

  required property ViewStyle theme
  // "body" | "bodySmall" | "caption"
  property string size: "bodySmall"
  // "normal" | "label" | "secondary"
  property string tone: "normal"

  textFormat: Text.PlainText
  color: root.theme.foreground
  opacity: root.tone === "label" ? root.theme.labelOpacity : root.tone === "secondary" ? root.theme.secondaryOpacity : 1
  font.family: root.theme.fontFamily
  font.pixelSize: root.theme.fontSize(root.size)
}
