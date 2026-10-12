import QtQuick
import qs.Commons

// One figure of a summary strip: small label over a bold value.
Column {
  id: stat

  property string label: ""
  property string value: ""
  property color foreground: Color.foreground
  property color valueColor: foreground
  property string fontFamily: Style.font.family

  spacing: Style.space(2)

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: stat.label
    color: stat.foreground
    opacity: 0.7
    font.family: stat.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: stat.value
    color: stat.valueColor
    font.family: stat.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    elide: Text.ElideRight
  }
}
