import QtQuick
import qs.Ui

// "Últimos ..." list: a header with an optional "Ver todo" link, an empty
// hint, the rows (each with a two-tap delete) and a footer. In the wide
// window it is always expanded, so the link and the separator are hidden.
Column {
  id: root

  required property ViewStyle theme
  // Shared two-tap delete state of the owning view.
  required property DeleteConfirm confirm
  property string title: ""
  property string emptyText: ""
  // [{ id, label, valueText, urgent }]
  property var rows: []
  // Confirm key prefix: "<prefix><row id>".
  property string keyPrefix: "hist:"
  property bool wide: false
  // The link shows while there is more to see and the list is not always expanded.
  property bool canExpand: false
  property bool expanded: false
  property string footerText: ""

  signal toggleRequested()
  signal deleteRequested(string id)

  spacing: root.theme.gap

  PanelSeparator { visible: !root.wide; foreground: root.theme.foreground }

  Item {
    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, toggle.implicitHeight)

    PanelSectionHeader {
      id: header
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: root.title
      foreground: root.theme.foreground
      fontFamily: root.theme.fontFamily
    }

    ViewButton {
      id: toggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      theme: root.theme
      role: "link"
      visible: !root.wide && root.canExpand
      text: root.expanded ? "Ver menos ‹" : "Ver todo ›"
      onClicked: root.toggleRequested()
    }
  }

  ViewText {
    visible: root.rows.length === 0
    width: parent.width
    theme: root.theme
    tone: "secondary"
    text: root.emptyText
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.rows

    HistoryRow {
      id: row
      required property var modelData
      width: parent.width
      theme: root.theme
      label: row.modelData.label
      valueText: row.modelData.valueText
      urgent: row.modelData.urgent
      deleteText: root.confirm.label(root.keyPrefix + row.modelData.id, "Eliminar")
      onDeleteRequested: root.confirm.ask(root.keyPrefix + row.modelData.id, function() { root.deleteRequested(row.modelData.id) })
    }
  }

  ViewText {
    visible: root.footerText !== ""
    width: parent.width
    theme: root.theme
    size: "caption"
    tone: "secondary"
    text: root.footerText
  }
}
