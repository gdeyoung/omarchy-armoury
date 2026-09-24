import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Advanced tab — GPU mode (dGPU machines), charge-threshold slider, firmware
// attribute browser, pending-reboot banner. Capability-gated throughout.
Column {
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.spacing.md

  // ===== GPU mode (only on machines with dgpu_disable / gpu_mux_mode) =====
  Column {
    width: parent.width
    visible: root.gpuCap.switchable && root.gpuOpts.length > 0
    spacing: Style.spacing.labelGap

    PanelSectionHeader {
      width: parent.width
      text: "GPU mode"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    ButtonGroup {
      width: parent.width
      foreground: root.foreground
      background: Color.background
      accent: root.accent
      fontFamily: root.fontFamily
      options: root.gpuOpts.map(function (m) { return m.label })
      value: {
        for (var i = 0; i < root.gpuOpts.length; i++)
          if (root.gpuOpts[i].key === root.gpuCurrent)
            return root.gpuOpts[i].label;
        return "";
      }
      onChanged: function (label) {
        for (var i = 0; i < root.gpuOpts.length; i++)
          if (root.gpuOpts[i].label === label)
            root.applyGpuMode(root.gpuOpts[i].key);
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: "Applies at next reboot"
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator {
    visible: root.gpuCap.switchable && root.gpuOpts.length > 0
    foreground: root.foreground
  }

  // ===== Charge threshold ==================================================
  Column {
    width: parent.width
    visible: root.state.battery.threshold >= 0
    spacing: Style.spacing.labelGap

    PanelSectionHeader {
      width: parent.width
      text: "Charge limit"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    InfoPair {
      width: parent.width
      label: "Stop charging at"
      value: root.state.battery.threshold + "%"
    }

    PanelSlider {
      width: parent.width
      bar: root.bar
      value: root.state.battery.threshold
      minimum: 20
      maximum: 100
      step: 5
      integer: true
      onLiveValueChanged: {
        if (!dragging && liveValue !== root.state.battery.threshold) {
          if (root.hostWidget && root.hostWidget.applyWrites)
            root.hostWidget.applyWrites("charge-limit", [{ verb: "charge-limit", value: Math.round(liveValue) }]);
        }
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: "Lower values extend battery lifespan; 100% disables limiting."
      color: root.foreground
      opacity: 0.5
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator {
    visible: root.state.battery.threshold >= 0
    foreground: root.foreground
  }

  // ===== Firmware attributes (read-only browser) ===========================
  Column {
    width: parent.width
    spacing: Style.spacing.labelGap

    PanelSectionHeader {
      width: parent.width
      text: "Firmware attributes"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Repeater {
      model: root.state.attrOrder
      InfoPair {
        width: parent ? parent.width : 0
        label: root.state.attrs[modelData] ? root.state.attrs[modelData].display : modelData
        value: root.state.attrs[modelData] ? root.state.attrs[modelData].current : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }

  // ===== Pending reboot banner =============================================
  Rectangle {
    visible: root.rebootPending
    width: parent.width
    height: bannerText.implicitHeight + Style.spacing.md
    radius: Style.cornerRadius
    color: Qt.rgba(1, 1, 1, 0.06)

    Text {
      id: bannerText
      anchors.centerIn: parent
      width: parent.width - Style.spacing.md
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: "Reboot pending to apply firmware change"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
