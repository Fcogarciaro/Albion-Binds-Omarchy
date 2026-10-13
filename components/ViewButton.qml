import QtQuick
import qs.Ui

// Button in the views' look, one font size per role:
//   action   bordered, body-small (primary and form buttons, chips)
//   compact  bordered, caption (delete, remove and other secondary actions)
//   link     borderless, caption ("Ver todo", repeat chip)
//   quiet    borderless, body-small (section toggles, the "⋯" menu)
Button {
  id: root

  required property ViewStyle theme
  property string role: "action"

  foreground: root.theme.foreground
  fontFamily: root.theme.fontFamily
  fontSize: root.role === "compact" || root.role === "link" ? root.theme.fontCaption : root.theme.fontBodySmall
  bordered: root.role === "action" || root.role === "compact"
}
