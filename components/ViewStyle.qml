import QtQuick
import qs.Commons

// Look shared by the Cultivos and Zona negra views and their subcomponents:
// colors, font, the two muted opacities, the spacing rhythm and the type scale.
// Each view builds one from its owner (Panel or Window) and passes it down, so
// no component repeats `owner.bar.foreground` / `owner.bar.fontFamily`.
QtObject {
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  // The large window scales type up by one factor so it does not look tiny.
  property bool wide: false

  readonly property real wideScale: 1.15
  readonly property real typeScale: wide ? wideScale : 1

  // Muted text: captions and labels, and secondary or empty-state text.
  readonly property real labelOpacity: 0.7
  readonly property real secondaryOpacity: 0.6

  // Spacing rhythm: inside a row, between items, between sections, between lanes.
  readonly property int gapTight: Style.space(4)
  readonly property int gap: Style.space(8)
  readonly property int gapSection: Style.space(12)
  readonly property int gapLane: Style.space(16)

  readonly property int fontCaption: Math.round(Style.font.caption * typeScale)
  readonly property int fontBodySmall: Math.round(Style.font.bodySmall * typeScale)
  readonly property int fontBody: Math.round(Style.font.body * typeScale)

  // "body" | "bodySmall" | "caption"
  function fontSize(name) {
    return name === "body" ? fontBody : name === "caption" ? fontCaption : fontBodySmall
  }
}
