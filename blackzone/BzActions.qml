import QtQuick
import "../components"

// The three capture actions (+ Botín, + Gasto, ✝ Muerte) and, when there is a
// previous expense, the "↻ Repetir" chip under them.
Column {
  id: root

  required property ViewStyle theme
  // Open compose card: "" | "loot" | "expense" | "death".
  property string composer: ""
  // Text of the repeat chip ("" hides it).
  property string repeatText: ""

  signal openRequested(string kind)
  signal repeatRequested()

  spacing: root.theme.gap

  Row {
    width: parent.width
    spacing: root.theme.gap

    ViewButton {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      text: "+ Botín"
      selected: root.composer === "loot"
      onClicked: root.openRequested("loot")
    }

    ViewButton {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      text: "+ Gasto"
      selected: root.composer === "expense"
      onClicked: root.openRequested("expense")
    }

    ViewButton {
      width: (parent.width - 2 * parent.spacing) / 3
      theme: root.theme
      text: "✝ Muerte"
      selected: root.composer === "death"
      onClicked: root.openRequested("death")
    }
  }

  ViewButton {
    visible: root.repeatText !== ""
    width: parent.width
    theme: root.theme
    role: "link"
    text: root.repeatText
    onClicked: root.repeatRequested()
  }
}
