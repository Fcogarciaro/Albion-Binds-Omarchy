import QtQuick
import qs.Commons
import qs.Ui
import "Farm.js" as Farm
import "../shared/ViewHelpers.js" as Helpers
import "../components"

// One plot: name, state, one contextual button (Plantar / Cosechar) and a "⋯"
// area with the two-tap secondary actions.
BorderSurface {
  id: root

  required property ViewStyle theme
  required property DeleteConfirm confirm
  property var plot: null
  // Open cycle (null when the plot is empty).
  property var cycle: null
  // "empty" | "planted" | "ready"
  property string status: "empty"
  // Display name of the open cycle's crop.
  property string cropLabel: ""
  // Lifetime totals { profit, cycles } or undefined.
  property var total: undefined
  // This plot's compose card is open.
  property bool formOpen: false
  // The "⋯" area with the secondary actions.
  property bool moreOpen: false

  signal actionRequested()
  signal cancelCycleRequested()
  signal removeRequested()

  radius: Style.cornerRadius
  color: root.formOpen ? Style.selectedFill : Style.normalFill
  borderSpec: Border.controlSpec("normal", root.theme.foreground, Color.accent)
  padding: root.theme.gapSection
  implicitHeight: inner.implicitHeight + contentTopInset + contentBottomInset

  Column {
    id: inner
    x: root.contentLeftInset
    y: root.contentTopInset
    width: root.width - root.contentLeftInset - root.contentRightInset
    spacing: root.theme.gap

    Item {
      width: parent.width
      implicitHeight: Math.max(labels.implicitHeight, actions.implicitHeight)

      Column {
        id: labels
        anchors.left: parent.left
        anchors.right: actions.left
        anchors.rightMargin: root.theme.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        ViewText {
          width: parent.width
          theme: root.theme
          size: "body"
          text: root.plot ? root.plot.name : ""
          font.bold: true
          elide: Text.ElideRight
        }

        ViewText {
          width: parent.width
          theme: root.theme
          tone: root.status === "empty" ? "secondary" : "normal"
          text: Farm.plotStateLabel(root.status) + (root.cycle ? " · " + root.cropLabel : "")
          color: root.status === "ready" ? Color.accent : root.theme.foreground
          font.bold: root.status === "ready"
          elide: Text.ElideRight
        }

        ViewText {
          visible: root.cycle !== null
          width: parent.width
          theme: root.theme
          size: "caption"
          tone: "label"
          text: root.cycle ? Farm.formatSilver(root.cycle.seedsPlanted) + " semillas · desde " + Helpers.shortDate(root.cycle.plantedAt) : ""
          elide: Text.ElideRight
        }

        ViewText {
          visible: root.total !== undefined
          width: parent.width
          theme: root.theme
          size: "caption"
          tone: "label"
          text: root.total ? "Total: " + Farm.signed(root.total.profit) + " · " + root.total.cycles + " ciclo(s)" : ""
          color: root.total && root.total.profit < 0 ? Color.urgent : root.theme.foreground
          elide: Text.ElideRight
        }
      }

      Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.theme.gapTight

        ViewButton {
          theme: root.theme
          text: root.cycle ? "Cosechar" : "Plantar"
          width: Math.max(implicitWidth, Style.space(92))
          selected: root.formOpen
          onClicked: root.actionRequested()
        }

        ViewButton {
          theme: root.theme
          role: "quiet"
          text: "⋯"
          tooltipText: "Más acciones"
          selected: root.moreOpen
          onClicked: { root.confirm.reset(); root.moreOpen = !root.moreOpen }
        }
      }
    }

    Row {
      visible: root.moreOpen
      spacing: root.theme.gap

      ViewButton {
        visible: root.cycle !== null
        theme: root.theme
        role: "compact"
        text: root.confirm.label("open:" + (root.cycle ? root.cycle.id : ""), "Cancelar siembra")
        onClicked: root.confirm.ask("open:" + root.cycle.id, function() { root.cancelCycleRequested() })
      }

      ViewButton {
        theme: root.theme
        role: "compact"
        text: root.confirm.label("plot:" + (root.plot ? root.plot.id : ""), "Eliminar parcela")
        onClicked: root.confirm.ask("plot:" + root.plot.id, function() { root.removeRequested() })
      }
    }
  }
}
