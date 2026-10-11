import QtQuick
import qs.Commons
import qs.Ui

// Zona negra tab: placeholder until the feature ships.
Column {
  id: view

  required property var owner
  property Item catcher: null
  readonly property bool editing: false

  spacing: Style.space(8)

  PanelSectionHeader {
    text: "ZONA NEGRA"
    foreground: owner.bar.foreground
    fontFamily: owner.bar.fontFamily
  }

  Text {
    width: parent.width
    text: "Próximamente"
    color: owner.bar.foreground
    font.family: owner.bar.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
  }

  Text {
    width: parent.width
    text: "Aquí vas a registrar tus sets y eventos en zona negra."
    color: owner.bar.foreground
    opacity: 0.6
    font.family: owner.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }
}
