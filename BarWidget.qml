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
  // A mode selection can imply several attribute writes; they run as one
  // queue through a single pkexec Process. verb validated by Model.validWrite.
  property var writeQueue: []
  property string writeLabel: ""

  function applyWrites(label, writes) {
    var q = [];
    for (var i = 0; i < writes.length; i++)
      if (Model.validWrite(writes[i].verb, writes[i].value, writes[i].index, writes[i].kind))
        q.push(writes[i]);
    if (q.length === 0) {
      writeResult = "invalid value";
      return;
    }
    if (writeProc.running || writeQueue.length > 0)
      return; // a write is already in flight; the panel re-triggers after
    writeQueue = q;
    writeLabel = label;
    writeBusy = true;
    writeResult = "";
    runNextWrite();
  }

  function runNextWrite() {
    if (writeQueue.length === 0) {
      writeBusy = false;
      refresh();
      return;
    }
    var item = writeQueue[0];
    writeQueue = writeQueue.slice(1);
    var cmd = ["pkexec", "omarchy-armoury-helper", item.verb];
    if (item.verb === "fan-point")
      cmd = cmd.concat([item.kind, String(item.index), String(item.value)]);
    else
      cmd.push(String(item.value));
    writeProc.command = cmd;
    writeProc.running = true;
  }

  Process {
    id: writeProc
    onExited: function (exitCode) {
      if (exitCode !== 0) {
        root.writeBusy = false;
        root.writeQueue = [];
        root.writeResult = "failed (exit " + exitCode + ")";
        root.refresh();
        return;
      }
      root.runNextWrite();
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
