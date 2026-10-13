import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "shared"
import "farm"
import "blackzone"
import "components"

// Large floating window for data entry (Cultivos and Zona negra). Opened with
// `omarchy-shell shell toggle fcogarcia.albion-companion '{}'`; the Atajos tab
// stays in the bar panel (Panel.qml).
//
// Same shape as the stock panels/wifiqr plugin: an Item with opened/open/close
// that owns a full-screen overlay PanelWindow (scrim, centered card).
Item {
  id: root

  // Injected by the shell for panel entry points.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  // Remembered in data.json (ui.tab), shared with the bar panel. The window has
  // no Atajos tab: "binds" opens Cultivos.
  readonly property string currentTab: DataStore.document.ui.tab === "blackzone" ? "blackzone" : "farm"

  readonly property bool editing: (currentTab === "farm" && farmView.editing)
    || (currentTab === "blackzone" && blackzoneView.editing)

  function open(payloadJson) {
    root.opened = true
    // The window is instantiated hidden, so `focus: true` is evaluated before
    // the surface is mapped and Escape would land nowhere. Re-acquire it after
    // mapping.
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "fcogarcia.albion-companion")
    else close()
  }

  // What the shared views expect from their owner (Panel.qml provides the same
  // shape): `store`, plus `bar.foreground` and `bar.fontFamily` for styling.
  // Colors come from the shell theme, like the stock popups.
  QtObject {
    id: viewOwner
    readonly property var store: DataStore
    readonly property QtObject bar: QtObject {
      readonly property color foreground: Color.popups.text
      readonly property string fontFamily: Style.font.family
    }
  }

  // Look of the window's own header (the views build theirs from viewOwner.bar).
  // Wide, so its type is scaled up like the views' in the large window.
  ViewStyle {
    id: look
    foreground: viewOwner.bar.foreground
    fontFamily: viewOwner.bar.fontFamily
    wide: true
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "albion-companion-window"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      // The shell's scrim token for full-screen dimming behind a popup.
      color: Color.menu.scrim

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing
      onCloseRequested: root.dismiss()
      onTabRequested: DataStore.setTab(root.currentTab === "farm" ? "blackzone" : "farm")

      Rectangle {
        id: card
        anchors.centerIn: parent
        // About 1000x700, clamped so it never overflows small outputs.
        width: Math.min(Style.space(1000), keyCatcher.width - Style.space(32))
        height: Math.min(Style.space(700), keyCatcher.height - Style.space(32))
        radius: Style.cornerRadius
        color: Color.popups.background
        border.color: Color.popups.border
        border.width: Style.normalBorderWidth

        // Swallow clicks so only the scrim outside the card dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: look.gapLane
          height: tabs.implicitHeight

          ViewText {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            theme: look
            size: "body"
            text: "Albion Companion"
            font.bold: true
          }

          ButtonGroup {
            id: tabs
            anchors.horizontalCenter: parent.horizontalCenter
            options: [
              { value: "farm", label: "Cultivos" },
              { value: "blackzone", label: "Zona negra" }
            ]
            value: root.currentTab
            focusable: false
            foreground: look.foreground
            fontFamily: look.fontFamily
            fontSize: look.fontBodySmall
            onChanged: function(v) { DataStore.setTab(v) }
          }

          ViewButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            theme: look
            text: "Cerrar"
            onClicked: root.dismiss()
          }
        }

        Flickable {
          id: scroller
          anchors.top: header.bottom
          anchors.topMargin: look.gapSection
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: look.gapLane
          clip: true
          contentWidth: width
          contentHeight: views.height
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: views
            width: scroller.width

            FarmView {
              id: farmView
              width: parent.width
              visible: root.currentTab === "farm"
              wide: true
              owner: viewOwner
              catcher: keyCatcher
            }

            BlackzoneView {
              id: blackzoneView
              width: parent.width
              visible: root.currentTab === "blackzone"
              wide: true
              owner: viewOwner
              catcher: keyCatcher
            }
          }
        }
      }
    }
  }
}
