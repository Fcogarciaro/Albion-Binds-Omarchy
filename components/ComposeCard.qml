import QtQuick
import qs.Commons
import qs.Ui

// Compose card shared by Zona negra and Cultivos: a bordered surface with a
// title and a close button. Only one card is open per tab at a time (the
// views decide which); the fields go inside as children.
BorderSurface {
  id: card

  property string title: ""
  required property ViewStyle theme
  // Item.children would swallow the header; fields go to the body column.
  default property alias content: body.data

  signal closeRequested()

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", card.theme.foreground, Color.accent)
  padding: card.theme.gapSection
  implicitHeight: inner.implicitHeight + contentTopInset + contentBottomInset

  Column {
    id: inner
    x: card.contentLeftInset
    y: card.contentTopInset
    width: card.width - card.contentLeftInset - card.contentRightInset
    spacing: card.theme.gap

    Item {
      width: parent.width
      implicitHeight: Math.max(titleText.implicitHeight, closeButton.implicitHeight)

      ViewText {
        id: titleText
        anchors.left: parent.left
        anchors.right: closeButton.left
        anchors.rightMargin: card.theme.gap
        anchors.verticalCenter: parent.verticalCenter
        theme: card.theme
        size: "body"
        text: card.title
        font.bold: true
        elide: Text.ElideRight
      }

      ViewButton {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "✕"
        tooltipText: "Cerrar"
        theme: card.theme
        role: "quiet"
        onClicked: card.closeRequested()
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: card.theme.gap
    }
  }
}
