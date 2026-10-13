import QtQuick
import qs.Commons
import "../farm/Farm.js" as Farm
import "../components"

// Top of the Zona negra tab: balance (with the "Guardado" notice), loot /
// deaths / expenses and the average loot per death plus the tomes.
Column {
  id: root

  required property ViewStyle theme
  // Blackzone.totals(...)
  property var sums: ({})
  property string savedText: ""
  // Extra lines under the stats ("" hides them).
  property string detail: ""

  spacing: root.theme.gap

  Item {
    width: parent.width
    implicitHeight: Math.max(balance.implicitHeight, saved.implicitHeight)

    ViewText {
      id: balance
      anchors.left: parent.left
      anchors.right: saved.visible ? saved.left : parent.right
      anchors.rightMargin: root.theme.gap
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      size: "body"
      text: (root.sums.profit > 0 ? "Ganancia: " : "Balance: ") + Farm.signed(root.sums.profit) + " plata"
      color: root.sums.profit < 0 ? Color.urgent : root.theme.foreground
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
      label: "Ganado (" + root.sums.loots + ")"
      value: Farm.formatSilver(root.sums.loot)
    }

    Stat {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      label: "Perdido (" + root.sums.deaths + ")"
      value: Farm.formatSilver(root.sums.lost)
    }

    Stat {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      label: "Gastado (" + root.sums.expenses + ")"
      value: Farm.formatSilver(root.sums.spent)
    }
  }

  ViewText {
    visible: root.detail !== ""
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "label"
    text: root.detail
    wrapMode: Text.WordWrap
  }
}
