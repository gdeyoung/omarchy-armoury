import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Fan tab — capability-gated fan-curve editor for machines exposing the
// asus-wmi fan-curve hwmon (pwm1_auto_point[1-8]_temp/_pwm + pwm1_enable).
// Hidden on machines without it (this Vivobook); the section below explains.
Column {
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.spacing.md

  readonly property var fc: root && root.state ? Model.fanControl(root.state) : { supported: false, points: [] }
  // Editing state: copy of the curve; changed flag drives the apply row.
  property var editPoints: []
  property bool dirty: false
  property bool seeded: false

  Component.onCompleted: resetEdit()

  // The Loader assigns root after load; seed the editor once real points
  // arrive (never re-seed: polls re-evaluate fc every few seconds and would
  // clobber in-progress edits).
  onFcChanged: if (!seeded && fc && fc.points && fc.points.length > 0) {
    seeded = true;
    resetEdit();
  }

  function resetEdit() {
    var pts = fc && fc.points && fc.points.length > 0 ? fc.points : defaultCurve();
    editPoints = pts.map(function (p) { return { temp: p.temp, pwm: p.pwm }; });
    dirty = false;
  }

  function defaultCurve() {
    return [
      { temp: 30, pwm: 0 }, { temp: 44, pwm: 64 }, { temp: 56, pwm: 128 },
      { temp: 66, pwm: 166 }, { temp: 74, pwm: 204 }, { temp: 82, pwm: 230 },
      { temp: 90, pwm: 255 }, { temp: 100, pwm: 255 }
    ];
  }

  function nudge(i, kind, delta) {
    var pts = editPoints.slice();
    var v = (kind === "temp" ? pts[i].temp : pts[i].pwm) + delta;
    var lo = kind === "temp" ? 30 : 0, hi = kind === "temp" ? 100 : 255;
    pts[i] = { temp: pts[i].temp, pwm: pts[i].pwm };
    pts[i][kind] = Math.max(lo, Math.min(hi, v));
    var check = Model.validateCurve(pts);
    if (!check.ok) return; // refuse edits that break monotonicity
    editPoints = pts;
    dirty = true;
  }

  function apply(activate) {
    var check = Model.validateCurve(editPoints);
    if (!check.ok) return;
    if (root.hostWidget && root.hostWidget.applyWrites)
      root.hostWidget.applyWrites(activate ? "fan-curve-apply" : "fan-curve-restore",
        Model.fanCurveWrites(check.points, activate));
    dirty = false;
  }

  // ===== Unsupported note (this machine) ====================================
  Column {
    width: parent.width
    visible: !fc.supported
    spacing: Style.spacing.labelGap

    PanelSectionHeader {
      width: parent.width
      text: "Fan curve"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: "Not exposed by this firmware. Machines that support it (most ROG/TUF) show an 8-point curve editor here — the same interface asusctl uses (pwm1_auto_point hwmon, kernel 5.17+)."
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // ===== Editor (supported machines) ========================================
  Column {
    width: parent.width
    visible: fc.supported
    spacing: Style.spacing.labelGap

    PanelSectionHeader {
      width: parent.width
      text: "Fan curve"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: fc.mode === "custom" ? "Custom curve active" : "BIOS default curve active"
      color: fc.mode === "custom" ? root.accent : root.foreground
      opacity: 0.8
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: editPoints.length

      delegate: Item {
        width: parent ? parent.width : 0
        required property int index
        implicitHeight: 30

        Text {
          id: idxLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(18)
          textFormat: Text.PlainText
          text: String(index + 1)
          color: root.foreground
          opacity: 0.5
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          anchors.left: idxLabel.right
          anchors.leftMargin: Style.spacing.sm
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.sm

          Stepper {
            label: Math.round(editPoints[index].temp) + "°C"
            onDown: nudge(index, "temp", -2)
            onUp: nudge(index, "temp", 2)
          }

          Stepper {
            label: Math.round(editPoints[index].pwm / 255 * 100) + "%"
            onDown: nudge(index, "pwm", -13)
            onUp: nudge(index, "pwm", 13)
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.spacing.sm

      Button {
        text: dirty ? "Apply + activate" : "Activate custom"
        enabled: Model.validateCurve(editPoints).ok
        onClicked: apply(true)
      }

      Button {
        text: "Restore BIOS curve"
        onClicked: {
          if (root.hostWidget && root.hostWidget.applyWrites)
            root.hostWidget.applyWrites("fan-bios", [{ verb: "fan-mode", value: 0 }]);
        }
      }
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
  }

  component Stepper: Row {
    property string label: ""
    signal down()
    signal up()
    spacing: 2

    Button {
      text: "−"
      onClicked: down()
    }
    Text {
      width: Style.space(52)
      horizontalAlignment: Text.AlignHCenter
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Button {
      text: "+"
      onClicked: up()
    }
  }
}
