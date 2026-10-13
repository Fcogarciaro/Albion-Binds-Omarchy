import QtQuick
import qs.Commons

// Two lanes side by side for the large window. The view's sections reparent
// into them when `wide` (`parent: view.wide ? lanes.leftLane : view`);
// otherwise they stay direct children of the view, in declaration order.
Row {
  id: root

  property bool wide: false
  property int laneSpacing: Style.space(16)
  property int sectionSpacing: Style.space(12)
  property alias leftLane: left
  property alias rightLane: right

  visible: root.wide
  spacing: root.laneSpacing

  Column {
    id: left
    width: (root.width - root.spacing) / 2
    spacing: root.sectionSpacing
  }

  Column {
    id: right
    width: (root.width - root.spacing) / 2
    spacing: root.sectionSpacing
  }
}
