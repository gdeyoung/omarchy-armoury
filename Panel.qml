import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Panel for gdeyoung.armoury — v0.3.0 tabbed redesign.
// Three tabs (Overview / Battery / Advanced), each its own file — a plain
// Column of width-bound, elided rows. Nothing is side-by-side except the
// hero, so nothing can overrun the card edge. State comes from the
// BarWidget (single probe owner); writes go through pkexec + polkit.
Panel {
  id: root
  moduleName: "gdeyoung.armoury"
  ipcTarget: "gdeyoung.armoury"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property int currentTab: 0

  readonly property var state: hostWidget && hostWidget.state ? hostWidget.state : Model.parseProbe("")
  readonly property var chargeMode: Model.chargeMode(state)
  readonly property bool rebootPending: Model.pendingReboot(state)
  readonly property var gpuCap: Model.gpuCapability(state)
  readonly property var gpuOpts: Model.gpuOptions(state)
  readonly property string gpuCurrent: Model.gpuMode(state) || ""
  readonly property var battery: Model.batteryStats(state)
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool writeBusy: hostWidget ? hostWidget.writeBusy : false
  readonly property string writeResult: hostWidget && hostWidget.writeResult !== undefined ? hostWidget.writeResult : ""

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
      health: root.battery.health,
      wear: root.battery.wear,
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

    function status(): string {
      return root.statusJson();
    }

    function selectTab(i: int): void {
      root.currentTab = Math.max(0, Math.min(3, i));
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
      // The KeyboardPanel contentHolder is already inset by card padding —
      // size to the ACTUAL available interior (stock panels use
      // scrollArea.availableWidth; contentWidth is the card's OUTER width).
      width: parent ? parent.width : panel.contentWidth
      spacing: Style.spacing.md

      // ===== Hero: identity =====
      PanelHero {
        width: parent.width
        title: "Armoury"
        meta: root.state.family || "ASUS"
        detail: (root.state.board !== "" ? root.state.board + " · " : "") + "BIOS " + (root.state.bios || "—")
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      ButtonGroup {
        width: parent.width
        foreground: root.foreground
        background: Color.background
        accent: root.accent
        fontFamily: root.fontFamily
        options: ["Overview", "Fan", "Battery", "Advanced"]
        value: ["Overview", "Fan", "Battery", "Advanced"][root.currentTab]
        onChanged: function (label) {
          root.currentTab = ["Overview", "Fan", "Battery", "Advanced"].indexOf(label);
        }
      }

      Loader {
        width: parent.width
        source: ["TabOverview.qml", "TabFan.qml", "TabBattery.qml", "TabAdvanced.qml"][root.currentTab]
        onLoaded: if (item) item.root = root
      }
    }
  }
}
