import QtQuick
import qs.Commons

// Shared label/value row: label left (55%), value right-aligned (45%),
// both width-bound and elided — cannot overflow the card.
Item {
  id: pair
  property string label: ""
  property string value: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  width: parent ? parent.width : 0
  implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

  Text {
    id: labelText
    anchors {
      left: parent.left
      right: valueText.left
      rightMargin: Style.spacing.sm
      verticalCenter: parent.verticalCenter
    }
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: pair.label
    color: pair.foreground
    opacity: 0.65
    font.family: pair.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    id: valueText
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: pair.value
    color: pair.foreground
    font.family: pair.fontFamily
    font.pixelSize: Style.font.body
  }
}
