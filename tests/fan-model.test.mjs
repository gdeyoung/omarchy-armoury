// Fan-curve logic: real fixture (unsupported iGPU box) + synthetic supported
// machine fixtures modeled on the asus-wmi fan-curve hwmon interface
// (pwm1_auto_point[1-8]_temp/_pwm, pwm1_enable 0=BIOS curve / 1=custom).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const Model = require(join(dirname(fileURLToPath(import.meta.url)), '..', 'Model.js'));

const FIXTURE = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), 'fixture-probe.json'), 'utf8');

function syntheticProbe(mode, points) {
  return JSON.stringify({
    attrs: [],
    battery: { status: 'Full', capacity: '100', threshold: '100' },
    fan: '2400',
    fanControl: { supported: true, mode: mode, raw: mode === 'custom' ? '1' : '0', points: points },
    temps: { cpu: 55, gpu: 48, nvme: 38 },
    profile: 'balanced', profiles: 'quiet balanced performance',
    bios: 'X', board: 'Y', family: 'ASUS'
  });
}

const CURVE = [
  { temp: 30, pwm: 0 }, { temp: 40, pwm: 13 }, { temp: 50, pwm: 26 },
  { temp: 60, pwm: 51 }, { temp: 70, pwm: 89 }, { temp: 80, pwm: 140 },
  { temp: 90, pwm: 166 }, { temp: 100, pwm: 166 }
];

test('real fixture (this machine): fan control unsupported, raw=2 reported', () => {
  const fc = Model.fanControl(Model.parseProbe(FIXTURE));
  assert.equal(fc.supported, false);
  assert.equal(fc.mode, null);
  assert.equal(fc.raw, '2');
  assert.deepEqual(fc.points, []);
});

test('supported machine: mode bios/custom decoded, 8 points parsed', () => {
  const fc = Model.fanControl(Model.parseProbe(syntheticProbe('custom', CURVE)));
  assert.equal(fc.supported, true);
  assert.equal(fc.mode, 'custom');
  assert.equal(fc.points.length, 8);
  assert.equal(fc.points[4].temp, 70);
  assert.equal(fc.points[4].pwm, 89);
});

test('validateCurve accepts a sane monotone curve and rounds values', () => {
  const v = Model.validateCurve([{ temp: 40.4, pwm: 13.6 }, { temp: 60, pwm: 51 }]);
  assert.equal(v.ok, true);
  assert.deepEqual(v.points, [{ temp: 40, pwm: 14 }, { temp: 60, pwm: 51 }]);
});

test('validateCurve rejects non-monotone and out-of-range curves', () => {
  assert.equal(Model.validateCurve([{ temp: 50, pwm: 100 }, { temp: 45, pwm: 120 }]).ok, false);
  assert.equal(Model.validateCurve([{ temp: 20, pwm: 0 }, { temp: 60, pwm: 10 }]).ok, false);
  assert.equal(Model.validateCurve([{ temp: 40, pwm: 300 }, { temp: 60, pwm: 300 }]).ok, false);
  assert.equal(Model.validateCurve([]).ok, false);
  assert.equal(Model.validateCurve([{ temp: 40, pwm: 100 }, { temp: 60, pwm: 50 }]).ok, false);
});

test('fanCurveWrites emits temp+pwm per point then the activate/restore bit', () => {
  const w = Model.fanCurveWrites(CURVE, true);
  assert.equal(w.length, 17); // 8*2 + 1
  assert.deepEqual(w[0], { verb: 'fan-point-temp', index: 1, value: 30 });
  assert.deepEqual(w[1], { verb: 'fan-point-pwm', index: 1, value: 0 });
  assert.deepEqual(w[15], { verb: 'fan-point-pwm', index: 8, value: 166 });
  assert.deepEqual(w[16], { verb: 'fan-mode', value: 1 });
  const r = Model.fanCurveWrites(CURVE, false);
  assert.equal(r[r.length - 1].value, 0);
});
