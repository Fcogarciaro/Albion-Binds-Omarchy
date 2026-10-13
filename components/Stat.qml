import QtQuick
import qs.Commons

// One figure of a summary strip: small label over a bold value.
Column {
  id: stat

  property string label: ""
  property string value: ""
  required property ViewStyle theme
  property color valueColor: theme.foreground

  spacing: Style.space(2)

  ViewText {
    width: parent.width
    theme: stat.theme
    size: "caption"
    tone: "label"
    text: stat.label
    elide: Text.ElideRight
  }

  ViewText {
    width: parent.width
    theme: stat.theme
    text: stat.value
    color: stat.valueColor
    font.bold: true
    elide: Text.ElideRight
  }
}
