import QtQuick
import qs.Commons
import "../components"

// Top of the Cultivos tab: total profit (with the "Guardado" notice) and the
// plot counters.
Column {
  id: root

  required property ViewStyle theme
  property string totalText: ""
  property bool urgent: false
  property string savedText: ""
  property int plotCount: 0
  property int growingCount: 0
  property int readyCount: 0

  spacing: root.theme.gap

  Item {
    width: parent.width
    implicitHeight: Math.max(total.implicitHeight, saved.implicitHeight)

    ViewText {
      id: total
      anchors.left: parent.left
      anchors.right: saved.visible ? saved.left : parent.right
      anchors.rightMargin: root.theme.gap
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      size: "body"
      text: root.totalText
      color: root.urgent ? Color.urgent : root.theme.foreground
      font.bold: true
      elide: Text.ElideRight
    }

    ViewText {
      id: saved
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      visible: root.savedText !== ""
      text: "✓ " + root.savedText
      color: Color.accent
      font.bold: true
    }
  }

  Row {
    width: parent.width
    spacing: root.theme.gap

    Stat {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      label: "Parcelas"
      value: String(root.plotCount)
    }

    Stat {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      label: "Creciendo"
      value: String(root.growingCount)
    }

    Stat {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      label: "Listas"
      value: String(root.readyCount)
      valueColor: root.readyCount > 0 ? Color.accent : root.theme.foreground
    }
  }
}
