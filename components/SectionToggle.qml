import QtQuick

// Header of a collapsible section: "Title ›" closed, "Title ⌄" open.
ViewButton {
  id: root

  property string title: ""
  property bool open: false

  signal toggled()

  role: "quiet"
  leftAlign: true
  text: root.title + " " + (root.open ? "⌄" : "›")
  onClicked: root.toggled()
}
