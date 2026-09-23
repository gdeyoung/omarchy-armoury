import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Panel for gdeyoung.armoury. Reads live state from the BarWidget's probe
// (the widget owns the single Process; the panel only reads root.state and
// calls its functions). Writes go through pkexec + the polkit helper.
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
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

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
      fan: root.state.fanRpm,
      profile: root.state.profile,
      chargeMode: root.chargeMode.current,
      chargeQuirk: root.chargeMode.quirk,
      threshold: root.state.battery.threshold,
      rebootPending: root.rebootPending
    });
  }

  function applyMode(value) {
    if (root.hostWidget && root.hostWidget.applyWrite)
      root.hostWidget.applyWrite("charge-mode", value);
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
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: panel.contentWidth
      spacing: Style.spacing.md

      // ===== Identity / hero =====
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.state.family || "ASUS"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
        Text {
          visible: root.state.board !== ""
          textFormat: Text.PlainText
          text: (root.state.board !== "" ? root.state.board + " · " : "") + (root.state.bios !== "" ? "BIOS " + root.state.bios : "")
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== Thermal snapshot =====
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap
        PanelSectionHeader {
          text: "Thermal"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Row {
          width: parent.width
          spacing: Style.spacing.lg
          InfoPair { label: "CPU"; value: fmtTemp(root.state.temps.cpu) }
          InfoPair { label: "GPU"; value: fmtTemp(root.state.temps.gpu) }
          InfoPair { label: "NVMe"; value: fmtTemp(root.state.temps.nvme) }
          InfoPair { label: "Fan"; value: Model.fanString(root.state.fanRpm) }
        }
        Text {
          visible: root.state.profile !== ""
          textFormat: Text.PlainText
          text: "Platform profile: " + root.state.profile + (root.state.epp !== "" ? " · EPP " + root.state.epp : "")
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== Battery care =====
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap
        PanelSectionHeader {
          text: "Battery care"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Text {
          visible: !root.chargeMode.supported
          textFormat: Text.PlainText
          text: "Not supported by this firmware"
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Repeater {
          model: root.chargeMode.options
          delegate: ModeRow {
            mode: modelData
            checked: root.chargeMode.current === modelData.value
            dimmed: root.chargeMode.quirk
            foreground: root.foreground
            fontFamily: root.fontFamily
            onPick: root.applyMode(modelData.value)
          }
        }
        Text {
          visible: root.chargeMode.supported && root.state.battery.threshold >= 0
          textFormat: Text.PlainText
          text: "Charge threshold: " + root.state.battery.threshold + "%" + (root.state.battery.status !== "" ? " · " + root.state.battery.status : "")
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          visible: root.chargeMode.quirk
          textFormat: Text.PlainText
          text: "Firmware reports raw value " + (root.chargeMode.rawValue || "?") + " — unknown mode; pick a mode to set one explicitly."
          color: root.foreground
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }
      }

      PanelSeparator {
        foreground: root.foreground
      }

      // ===== Firmware attributes (all, read-only) =====
      Column {
        width: parent.width
        spacing: Style.spacing.labelGap
        PanelSectionHeader {
          text: "Firmware attributes"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Repeater {
          model: root.state.attrOrder
          delegate: InfoPair {
            width: parent.width
            label: root.state.attrs[modelData] ? root.state.attrs[modelData].display : modelData
            value: root.state.attrs[modelData] ? root.state.attrs[modelData].current : ""
          }
        }
      }

      // ===== Pending reboot banner =====
      Rectangle {
        visible: root.rebootPending
        width: parent.width
        height: 28
        radius: Style.cornerRadius
        color: Qt.rgba(1, 1, 1, 0.06)
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "Reboot pending to apply firmware change"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  function fmtTemp(t) {
    return t === null || t === undefined ? "—" : Math.round(t) + "°C";
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    spacing: Style.spacing.lg
    Text {
      textFormat: Text.PlainText
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      textFormat: Text.PlainText
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  component ModeRow: Item {
    id: row
    property var mode
    property bool checked: false
    property bool dimmed: false
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    signal pick(int value)
    width: parent.width
    implicitHeight: Math.max(modeLabel.implicitHeight, dot.implicitHeight) + Style.spacing.md
    Rectangle {
      anchors.fill: parent
      visible: mouse.hovered
      color: Qt.rgba(1, 1, 1, 0.06)
    }
    Text {
      id: modeLabel
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: row.mode.label
      color: row.foreground
      font.family: row.fontFamily
      font.pixelSize: Style.font.body
      opacity: row.dimmed ? 0.8 : 1.0
    }
    Text {
      id: hint
      anchors.left: modeLabel.right
      anchors.leftMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: row.mode.hint
      color: row.foreground
      opacity: 0.45
      font.family: row.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: dot
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.sm
      anchors.verticalCenter: parent.verticalCenter
      text: row.checked ? "●" : ""
      color: Color.accent
      font.family: row.fontFamily
      font.pixelSize: Style.font.body
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.pick(row.mode.value)
    }
  }
}
