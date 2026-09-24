import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Panel for gdeyoung.armoury — G-Helper-inspired layout: big CPU/GPU temp
// readouts with level bars, segmented mode selectors, capability-gated GPU
// section. Reads state from the BarWidget (single probe owner); writes go
// through pkexec + the polkit helper. Every Text is width-constrained —
// nothing may overflow the card.
Panel {
  id: root
  moduleName: "gdeyoung.armoury"
  ipcTarget: "gdeyoung.armoury"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var state: hostWidget && hostWidget.state ? hostWidget.state : Model.parseProbe("")
  readonly property var chargeMode: Model.chargeMode(state)
  readonly property bool rebootPending: Model.pendingReboot(state)
  readonly property var gpuCap: Model.gpuCapability(state)
  readonly property var gpuOpts: Model.gpuOptions(state)
  readonly property string gpuCurrent: Model.gpuMode(state) || ""
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string iconFont: Style.font.iconFont
  readonly property bool writeBusy: hostWidget ? hostWidget.writeBusy : false
  readonly property string writeResult: hostWidget ? hostWidget.writeResult : ""

  // Fast poll while the panel is open: 3 s.
  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
  }

  function statusJson() {
    return JSON.stringify({
      opened: root.opened,
      cpu: root.state.temps.cpu,
      gpu: root.state.temps.gpu,
      fan: root.state.fanRpm,
      profile: root.state.profile,
      chargeMode: root.chargeMode.current,
      chargeQuirk: root.chargeMode.quirk,
      threshold: root.state.battery.threshold,
      gpuMode: root.gpuCurrent,
      gpuSwitchable: root.gpuCap.switchable,
      rebootPending: root.rebootPending
    });
  }

  function applyMode(value) {
    if (root.hostWidget && root.hostWidget.applyWrites)
      root.hostWidget.applyWrites("charge-mode", [{ verb: "charge-mode", value: value }]);
  }

  function applyGpuMode(mode) {
    if (root.hostWidget && root.hostWidget.applyWrites)
      root.hostWidget.applyWrites("gpu-mode", Model.gpuWrites(mode));
  }

  IpcHandler {
    target: "gdeyoung.armoury"

    function open(): void {
      root.open();
    }

    function close(): void {
      root.close();
    }

    function toggle(): void {
      root.toggle();
    }

    function status(): string {
      return root.statusJson();
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: panel.contentWidth
      spacing: Style.spacing.md

      // ===== Identity hero =====
      Row {
        width: parent.width
        spacing: Style.spacing.md

        Text {
          id: heroIcon
          text: ""
          color: root.accent
          font.family: root.iconFont
          font.pixelSize: Style.font.title
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - heroIcon.width - parent.spacing
          spacing: 2
          anchors.verticalCenter: parent.verticalCenter

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.state.family || "ASUS"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            visible: root.state.board !== "" || root.state.bios !== ""
            text: (root.state.board !== "" ? root.state.board : "") + (root.state.bios !== "" ? (root.state.board !== "" ? " · " : "") + "BIOS " + root.state.bios : "")
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            visible: root.state.profile !== ""
            text: "Platform: " + root.state.profile + (root.state.epp !== "" ? " · EPP " + root.state.epp : "")
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== Big temp readouts (G-Helper style) =====
      Row {
        width: parent.width
        spacing: Style.spacing.lg

        TempGauge {
          width: (parent.width - parent.spacing) / 2
          label: "CPU"
          temp: root.state.temps.cpu
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
        }

        TempGauge {
          width: (parent.width - parent.spacing) / 2
          label: "GPU"
          temp: root.state.temps.gpu
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
        }
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "Fan " + Model.fanString(root.state.fanRpm) + (root.state.temps.nvme !== null ? " · NVMe " + Math.round(root.state.temps.nvme) + "°C" : "")
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== GPU mode (dGPU machines only) =====
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

      // ===== Battery care =====
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap

        PanelSectionHeader {
          width: parent.width
          text: "Battery care"
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
          visible: root.chargeMode.supported && root.state.battery.threshold >= 0
          width: parent.width
          textFormat: Text.PlainText
          text: "Charge threshold: " + root.state.battery.threshold + "%" + (root.state.battery.status !== "" ? " · " + root.state.battery.status : "")
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          visible: root.chargeMode.quirk
          width: parent.width
          textFormat: Text.PlainText
          text: "Firmware reports raw value " + (root.chargeMode.rawValue || "?") + " — unknown mode; pick a mode to set one explicitly."
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.writeBusy || (root.writeResult !== "" && root.writeResult !== "applied")
          width: parent.width
          textFormat: Text.PlainText
          text: root.writeBusy ? "Applying…" : root.writeResult
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== Firmware attributes (read-only) =====
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
          delegate: AttrRow {
            width: column.width
            name: root.state.attrs[modelData] ? root.state.attrs[modelData].display : modelData
            value: root.state.attrs[modelData] ? root.state.attrs[modelData].current : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
        }
      }

      // ===== Pending reboot banner =====
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
          text: "Reboot pending to apply firmware change"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  // G-Helper-style big readout: label, big °C number, level bar.
  component TempGauge: Column {
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

  component AttrRow: Item {
    property string name: ""
    property string value: ""
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    height: nameText.implicitHeight
    implicitHeight: nameText.implicitHeight

    Text {
      id: nameText
      anchors.left: parent.left
      anchors.right: valueText.left
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: name
      color: foreground
      opacity: 0.6
      font.family: fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: valueText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: value
      color: foreground
      font.family: fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
