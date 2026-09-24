// Model.js — pure parse/format logic for gdeyoung.armoury.
// No Qt imports: loads from QML (import "Model.js" as Model) and node (require) for tests.
// Charge-care decode facts live in the kit: system/armoury-charge-test.log.

// Charge-care mode labels. asus-armoury exposes charge_mode as 0;1;2 on this
// board; the ASUS triad is Standard / Balanced / Maximum Lifespan and the
// decode test (kit system/armoury-charge-test.sh) pins which integer is
// which via the charge_control_end_threshold readback.
var CHARGE_MODES = [
  { value: 0, key: "standard", label: "Standard", hint: "charges to 100%" },
  { value: 1, key: "balanced", label: "Balanced", hint: "limits charge, best mix" },
  { value: 2, key: "lifespan", label: "Maximum lifespan", hint: "lowest charge, best battery health" }
];

// GPU modes (G-Helper semantics on the asus-armoury attributes):
//   dgpu_disable: 0 = dGPU enabled, 1 = dGPU disabled (Integrated/"Eco")
//   gpu_mux_mode: 0 = hybrid display path, 1 = dGPU drives the panel (Ultimate)
// Both apply at next reboot. Which attrs exist varies per model.
var GPU_MODES = [
  { key: "hybrid", label: "Hybrid", needsDgpu: false, needsMux: false,
    writes: [ { verb: "gpu-disable", value: 0 } ],
    hint: "iGPU + dGPU on demand" },
  { key: "integrated", label: "Integrated", needsDgpu: true, needsMux: false,
    writes: [ { verb: "gpu-disable", value: 1 } ],
    hint: "dGPU off, best battery" },
  { key: "ultimate", label: "Ultimate", needsDgpu: false, needsMux: true,
    writes: [ { verb: "gpu-mux", value: 1 } ],
    hint: "dGPU drives the display" }
];

function gpuCapability(state) {
  var dg = state && state.attrs ? state.attrs["dgpu_disable"] : null;
  var mux = state && state.attrs ? state.attrs["gpu_mux_mode"] : null;
  return { dgpu: !!dg, mux: !!mux, switchable: !!dg || !!mux };
}

function gpuOptions(state) {
  var cap = gpuCapability(state);
  if (!cap.switchable) return [];
  var out = [];
  for (var i = 0; i < GPU_MODES.length; i++) {
    var m = GPU_MODES[i];
    if (m.needsDgpu && !cap.dgpu) continue;
    if (m.needsMux && !cap.mux) continue;
    out.push(m);
  }
  return out;
}

function gpuMode(state) {
  var cap = gpuCapability(state);
  if (!cap.switchable) return null;
  var mux = state.attrs["gpu_mux_mode"];
  var dg = state.attrs["dgpu_disable"];
  if (cap.mux && mux && mux.current === "1") return "ultimate";
  if (cap.dgpu && dg && dg.current === "1") return "integrated";
  return "hybrid";
}

// Temp color thresholds (CPU Tctl, Strix Point spec max 100C).
function tempLevel(c) {
  if (c === null || c === undefined || isNaN(c)) return "ok";
  if (c >= 90) return "hot";
  if (c >= 75) return "warm";
  return "ok";
}

function fanString(rpm) {
  if (!rpm || rpm <= 0) return "idle";
  return rpm + " rpm";
}

function parseProbe(text) {
  var out = {
    ok: false, attrs: {}, attrOrder: [], battery: { status: "", capacity: -1, threshold: -1 },
    fanRpm: 0, temps: { cpu: null, gpu: null, nvme: null },
    profile: "", profiles: [], epp: "", bios: "", board: "", family: ""
  };
  var d = null;
  try { d = JSON.parse(String(text)); } catch (e) { return out; }
  if (!d || typeof d !== "object") return out;
  out.ok = true;

  var list = Array.isArray(d.attrs) ? d.attrs : [];
  for (var i = 0; i < list.length; i++) {
    var a = list[i] || {};
    if (!a.name) continue;
    out.attrs[a.name] = {
      display: String(a.display || a.name),
      current: String(a.current === null || a.current === undefined ? "" : a.current),
      possible: String(a.possible || "").split(";").filter(function (x) { return x !== ""; }),
      type: String(a.type || "")
    };
    out.attrOrder.push(String(a.name));
  }

  var b = d.battery || {};
  out.battery.status = String(b.status || "");
  out.battery.capacity = numOr(b.capacity, -1);
  out.battery.threshold = numOr(b.threshold, -1);

  out.fanRpm = numOr(d.fan, 0);
  var t = d.temps || {};
  out.temps.cpu = numOrNull(t.cpu);
  out.temps.gpu = numOrNull(t.gpu);
  out.temps.nvme = numOrNull(t.nvme);

  out.profile = String(d.profile || "");
  out.profiles = String(d.profiles || "").split(/\s+/).filter(function (x) { return x !== ""; });
  out.epp = String(d.epp || "");
  out.bios = String(d.bios || "");
  out.board = String(d.board || "");
  out.family = String(d.family || "");
  return out;
}

function numOr(v, fallback) {
  var n = Number(v);
  return isNaN(n) ? fallback : n;
}

function numOrNull(v) {
  return v === null || v === undefined || v === "" ? null : numOr(v, null);
}

// charge-mode state from parsed probe.
// supported: firmware attribute exists.
// current: integer value, or null when firmware reports something outside
//   possible_values (this board has been observed reporting "10") — quirk=true.
// expectedThreshold: what the battery threshold SHOULD read for each mode
//   according to the decode test; used only as a hint label, never asserted.
function chargeMode(state) {
  var attr = state && state.attrs ? state.attrs["charge_mode"] : null;
  if (!attr) return { supported: false, current: null, quirk: false, options: CHARGE_MODES };
  var cur = null;
  var valid = attr.possible.length === 0 || attr.possible.indexOf(attr.current) >= 0;
  if (valid) cur = numOr(attr.current, null);
  var opts = [];
  for (var i = 0; i < CHARGE_MODES.length; i++) {
    var m = CHARGE_MODES[i];
    if (attr.possible.length === 0 || attr.possible.indexOf(String(m.value)) >= 0)
      opts.push(m);
  }
  return {
    supported: true,
    current: cur,
    quirk: !valid,
    rawValue: attr.current,
    options: opts.length > 0 ? opts : CHARGE_MODES
  };
}

function chargeModeLabel(value) {
  for (var i = 0; i < CHARGE_MODES.length; i++)
    if (CHARGE_MODES[i].value === value) return CHARGE_MODES[i].label;
  return value === null || value === undefined ? "Unknown" : "Mode " + value;
}

function pendingReboot(state) {
  var a = state && state.attrs ? state.attrs["pending_reboot"] : null;
  if (!a) return false;
  return Number(a.current) > 0;
}

function identityLines(state) {
  var lines = [];
  if (state.family) lines.push(state.family + (state.board ? " (" + state.board + ")" : ""));
  if (state.bios) lines.push("BIOS " + state.bios);
  return lines;
}

// Sanity check a helper write before spawning pkexec: verb + strict value.
function validWrite(verb, value) {
  if (verb === "charge-mode") return [0, 1, 2].indexOf(Number(value)) >= 0;
  if (verb === "charge-limit") { var n = Number(value); return n >= 20 && n <= 100; }
  if (verb === "gpu-disable") return Number(value) === 0 || Number(value) === 1;
  if (verb === "gpu-mux") return Number(value) === 0 || Number(value) === 1;
  return false;
}

// All writes a GPU mode selection implies (may be more than one attribute).
function gpuWrites(modeKey) {
  for (var i = 0; i < GPU_MODES.length; i++)
    if (GPU_MODES[i].key === modeKey)
      return GPU_MODES[i].writes;
  return [];
}

// node (tests) export — QML ignores this block.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    CHARGE_MODES, GPU_MODES, tempLevel, fanString, parseProbe,
    chargeMode, chargeModeLabel, pendingReboot, identityLines, validWrite,
    gpuCapability, gpuOptions, gpuMode, gpuWrites
  };
}
