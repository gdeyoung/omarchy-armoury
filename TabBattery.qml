import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Battery tab — big health readout, care mode selector, threshold, live stats.
Column {
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.spacing.md

  // Health hero: big % number + wear caption.
  Item {
    width: parent.width
    height: big.implicitHeight + cap.implicitHeight

    Text {
      id: big
      anchors.left: parent.left
      anchors.top: parent.top
      textFormat: Text.PlainText
      text: root.battery.health !== null ? root.battery.health + "%" : "—"
      color: root.battery.health !== null && root.battery.health < 70 ? (bar ? bar.urgent : Color.urgent) : root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
    }

    Text {
      id: cap
      anchors.left: parent.left
      anchors.top: big.bottom
      anchors.topMargin: 2
      textFormat: Text.PlainText
      text: "Battery health (full ÷ design capacity)"
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.sm
      anchors.baseline: big.baseline
      textFormat: Text.PlainText
      text: root.battery.wear !== null ? root.battery.wear + "% wear" : ""
      color: root.foreground
      opacity: 0.6
    }
  }

  PanelSeparator {
    foreground: root.foreground
  }

  PanelSectionHeader {
    width: parent.width
    text: "Charge care mode"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: !root.chargeMode.supported
    width: parent.width
    textFormat: Text.PlainText
    text: "Not supported by this firmware"
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  ButtonGroup {
    visible: root.chargeMode.supported && root.chargeMode.options.length > 0
    width: parent.width
    foreground: root.foreground
    background: Color.background
    accent: root.accent
    fontFamily: root.fontFamily
    options: root.chargeMode.options.map(function (m) { return m.label })
    value: root.chargeMode.current !== null ? Model.chargeModeLabel(root.chargeMode.current) : ""
    onChanged: function (label) {
      for (var i = 0; i < root.chargeMode.options.length; i++)
        if (root.chargeMode.options[i].label === label)
          root.applyMode(root.chargeMode.options[i].value);
    }
  }

  Text {
    visible: root.chargeMode.quirk
    width: parent.width
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: "Firmware reports raw value " + (root.chargeMode.rawValue || "?") + " — unknown mode; pick a mode to set one explicitly."
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    visible: root.writeBusy || (root.writeResult !== "" && root.writeResult !== "applied")
    width: parent.width
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: root.writeBusy ? "Applying…" : root.writeResult
    color: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  PanelSeparator {
    foreground: root.foreground
  }

  PanelSectionHeader {
    width: parent.width
    text: "Live"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  InfoPair { label: "Status"; value: root.battery.status }
  InfoPair { label: "Charge"; value: root.battery.percent !== null ? root.battery.percent + "%" : "—" }
  InfoPair { label: "Draw"; value: root.battery.watts !== null ? root.battery.watts + " W" : "—" }
  InfoPair { label: "Cycles"; value: root.battery.cycles !== null ? String(root.battery.cycles) : "—" }
  InfoPair { label: "Charge threshold"; value: root.state.battery.threshold >= 0 ? root.state.battery.threshold + "%" : "—" }
}
