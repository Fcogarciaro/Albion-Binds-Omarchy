import QtQuick
import qs.Commons
import qs.Ui

// Compose card shared by Zona negra and Cultivos: a bordered surface with a
// title and a close button. Only one card is open per tab at a time (the
// views decide which); the fields go inside as children.
BorderSurface {
  id: card

  property string title: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  // Item.children would swallow the header; fields go to the body column.
  default property alias content: body.data

  signal closeRequested()

  radius: Style.cornerRadius
  color: Style.normalFill
  borderSpec: Border.controlSpec("normal", card.foreground, Color.accent)
  padding: Style.space(10)
  implicitHeight: inner.implicitHeight + contentTopInset + contentBottomInset

  Column {
    id: inner
    x: card.contentLeftInset
    y: card.contentTopInset
    width: card.width - card.contentLeftInset - card.contentRightInset
    spacing: Style.space(8)

    Item {
      width: parent.width
      implicitHeight: Math.max(titleText.implicitHeight, closeButton.implicitHeight)

      Text {
        id: titleText
        anchors.left: parent.left
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: card.title
        color: card.foreground
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Button {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "✕"
        tooltipText: "Cerrar"
        foreground: card.foreground
        fontFamily: card.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: card.closeRequested()
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: Style.space(8)
    }
  }
}
