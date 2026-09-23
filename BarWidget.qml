import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry for gdeyoung.armoury: CPU temperature chip + icon, click opens
// the panel. Reads via the stateless armoury.sh probe; writes (battery care
// mode, charge limit) go through pkexec + the polkit helper. Right click
// forces a refresh, middle click cycles chip label modes.
BarWidget {
  id: root

  moduleName: "gdeyoung.armoury"

  readonly property string scriptPath: Qt.resolvedUrl("armoury.sh").toString().replace("file://", "")
  property var state: Model.parseProbe("")
  // Manifest settings (barWidget.schema), applied at load; middle-click
  // cycling is session-local.
  readonly property var sv: settings || ({})
  // Session-local override; falls back to the manifest chipMode setting.
  property int labelOverride: -1
  readonly property int labelMode: labelOverride >= 0 ? labelOverride : ["temp", "profile", "fan", "off"].indexOf(sv.chipMode || "temp")
  readonly property int refreshSecs: Math.max(5, Number(sv.refreshSeconds) || 30)
  property string writeResult: ""
  property bool writeBusy: false

  // Ambient poll: slow (30s) — temps/profile drift gently. The panel-driven
  // fast poll lives in Panel.qml while it is open.
  Process {
    id: probe
    command: ["/bin/bash", root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = Model.parseProbe(text);
        if (next.ok)
          root.state = next;
      }
    }
  }

  Timer {
    interval: root.refreshSecs * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }

  function refresh() {
    if (!probe.running)
      probe.running = true;
  }

  // --- writes (polkit-gated) ---------------------------------------------
  // verb validated by Model.validWrite; value is a strict integer/string.
  function applyWrite(verb, value) {
    if (!Model.validWrite(verb, value)) {
      writeResult = "invalid value";
      return;
    }
    if (writeProc.running)
      return;
    writeBusy = true;
    writeResult = "";
    writeProc.command = ["pkexec", "omarchy-armoury-helper", verb, String(value)];
    writeProc.running = true;
  }

  Process {
    id: writeProc
    onExited: function (exitCode) {
      root.writeBusy = false;
      root.writeResult = exitCode === 0 ? "applied" : "failed (exit " + exitCode + ")";
      root.refresh();
    }
  }

  // --- bar label ----------------------------------------------------------
  readonly property color tempColor: {
    var lvl = Model.tempLevel(state.temps.cpu);
    if (lvl === "hot") return bar ? bar.urgent : Color.urgent;
    if (lvl === "warm") return Qt.rgba(0.95, 0.65, 0.25, 1.0); // amber
    return bar ? bar.barForeground : Color.foreground;
  }
  readonly property string chipText: {
    if (labelMode === 1)
      return state.profile !== "" ? state.profile.charAt(0).toUpperCase() + state.profile.slice(1) : "";
    if (labelMode === 2)
      return state.fanRpm > 0 ? state.fanRpm + "rpm" : "";
    if (labelMode === 3)
      return "";
    return state.temps.cpu !== null && state.temps.cpu !== undefined ? Math.round(state.temps.cpu) + "°" : "";
  }

  function cycleLabel() {
    labelOverride = (labelMode + 1) % 4;
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    var target = panelLoader.item;
    if (!target)
      return;
    if ("bar" in target)
      target.bar = root.bar;
    if ("anchorItem" in target)
      target.anchorItem = button;
    if ("hostWidget" in target)
      target.hostWidget = root;
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle)
      panelLoader.item.toggle();
  }

  // PopupCard outside-click dismissal routes through the owner; without this
  // the popup wedges after the first outside-click close (see powercore v0.2.0).
  function close() {
    if (panelLoader.item && panelLoader.item.close)
      panelLoader.item.close();
  }

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
   source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      var parts = [];
      if (root.chipText !== "")
        parts.push(root.chipText);
      parts.push(""); // nf-f2c7 thermometer (literal glyph; verified in JetBrainsMono NF cmap)
      return parts.join(" ");
    }
    // Fixed slots so the bar never shifts between ticks: label + icon.
    slotSize: Style.bar.iconSlot * (root.chipText !== "" ? 2 : 1)
    foreground: root.tempColor
    onPressed: function (b) {
      if (b === Qt.RightButton)
        root.refresh();
      else if (b === Qt.MiddleButton)
        root.cycleLabel();
      else if (b === Qt.LeftButton)
        root.togglePanel();
    }
  }
}
