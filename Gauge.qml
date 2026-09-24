import QtQuick
import qs.Commons
import "Model.js" as Model

// Shared full-width temperature gauge: label left, big colored readout
// right (inset from the card edge), proportional level bar underneath.
Column {
  id: gauge
  property string label: ""
  property real temp: 0
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  spacing: Style.spacing.labelGap

  readonly property real clamped: Math.max(0, Math.min(105, temp))
  readonly property string level: Model.tempLevel(temp)
  readonly property color levelColor: level === "hot" ? (bar ? bar.urgent : Color.urgent) : (level === "warm" ? Qt.rgba(0.95, 0.65, 0.25, 1.0) : accent)

  Item {
    width: parent.width
    height: big.implicitHeight

    Text {
      id: gaugeLabel
      anchors.left: parent.left
      anchors.baseline: big.baseline
      textFormat: Text.PlainText
      text: gauge.label
      color: gauge.foreground
      opacity: 0.6
      font.family: gauge.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      id: big
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.md
      textFormat: Text.PlainText
      text: gauge.temp !== null && gauge.temp !== undefined && !isNaN(gauge.temp) ? Math.round(gauge.temp) + "°" : "—"
      color: gauge.levelColor
      font.family: gauge.fontFamily
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
    }
  }

  Rectangle {
    width: parent.width
    height: 4
    radius: 2
    color: Qt.rgba(1, 1, 1, 0.10)

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Math.round(parent.width * (gauge.clamped / 105))
      radius: 2
      color: gauge.levelColor
      Behavior on width {
        NumberAnimation {
          duration: 400
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 400
        }
      }
    }
  }
}
