import QtQuick
import qs.Commons
import "Model.js" as Model

// Overview tab — stacked full-width gauges (no side-by-side math can
// overrun the card), fan/NVMe line, platform profile line.
Column {
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.spacing.md

  Gauge {
    width: parent.width
    label: "CPU"
    temp: root.state.temps.cpu
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
  }

  Gauge {
    width: parent.width
    label: "GPU"
    temp: root.state.temps.gpu
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
  }

  Text {
    width: parent.width
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: "Fan " + Model.fanString(root.state.fanRpm)
      + (root.state.temps.nvme !== null ? " · NVMe " + Math.round(root.state.temps.nvme) + "°C" : "")
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    width: parent.width
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: "Platform profile " + (root.state.profile || "—")
      + (root.state.epp !== "" ? " · EPP " + root.state.epp : "")
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
