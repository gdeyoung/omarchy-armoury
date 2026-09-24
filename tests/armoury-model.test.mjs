// Real probe output captured from this machine (2026-09-23), plus edge cases.
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

test('parseProbe parses the real captured probe line', () => {
  const s = Model.parseProbe(FIXTURE);
  assert.equal(s.ok, true);
  assert.equal(s.attrOrder.length, 2);
  assert.deepEqual(s.attrs['charge_mode'].possible, ['0', '1', '2']);
  assert.equal(s.battery.threshold, 100);
  assert.equal(s.battery.capacity, 100);
  assert.ok(s.fanRpm > 0 && s.fanRpm < 20000, 'fan rpm sane: ' + s.fanRpm);
  // Volatile sensors: sanity ranges, not exact pins (fixture is a live capture).
  assert.ok(s.temps.cpu > 25 && s.temps.cpu < 105, 'cpu temp sane');
  assert.ok(s.temps.gpu > 20 && s.temps.gpu < 105, 'gpu temp sane');
  assert.ok(s.temps.nvme > 15 && s.temps.nvme < 90, 'nvme temp sane');
  assert.ok(['quiet', 'balanced', 'performance'].includes(s.profile), 'profile is one of the choices: ' + s.profile);
  assert.deepEqual(s.profiles, ['quiet', 'balanced', 'performance']);
  assert.equal(s.bios, 'M5606WA.316');
});

test('batteryStats computes health, wear, watts from the live capture', () => {
  const s = Model.batteryStats(Model.parseProbe(FIXTURE));
  assert.equal(s.status, 'Full');
  assert.equal(s.percent, 100);
  assert.ok(s.health > 85 && s.health < 95, 'health sane: ' + s.health);
  assert.ok(Math.abs(s.wear - (100 - s.health)) < 0.2, 'wear complements health');
  assert.equal(typeof s.watts, 'number');
});

test('parseProbe survives garbage and empty input', () => {
  assert.equal(Model.parseProbe('').ok, false);
  assert.equal(Model.parseProbe('not json').ok, false);
  const s = Model.parseProbe('{"attrs":null,"temps":{}}');
  assert.equal(s.ok, true);
  assert.equal(s.temps.cpu, null);
  assert.deepEqual(s.profiles, []);
});

test('chargeMode detects the out-of-range firmware quirk', () => {
  // Captured reality: current_value "10", possible "0;1;2".
  const s = Model.parseProbe(FIXTURE);
  const cm = Model.chargeMode(s);
  assert.equal(cm.supported, true);
  assert.equal(cm.current, null);
  assert.equal(cm.quirk, true);
  assert.equal(cm.rawValue, '10');
  assert.equal(cm.options.length, 3);
});

test('chargeMode resolves a normal value', () => {
  const s = Model.parseProbe(FIXTURE.replace('"current":"10"', '"current":"1"'));
  const cm = Model.chargeMode(s);
  assert.equal(cm.supported, true);
  assert.equal(cm.current, 1);
  assert.equal(cm.quirk, false);
  assert.equal(Model.chargeModeLabel(cm.current), 'Balanced');
});

test('chargeMode on a machine without the attribute', () => {
  const s = Model.parseProbe('{"attrs":[]}');
  const cm = Model.chargeMode(s);
  assert.equal(cm.supported, false);
  assert.equal(cm.current, null);
});

test('tempLevel boundaries', () => {
  assert.equal(Model.tempLevel(40), 'ok');
  assert.equal(Model.tempLevel(74.9), 'ok');
  assert.equal(Model.tempLevel(75), 'warm');
  assert.equal(Model.tempLevel(89.9), 'warm');
  assert.equal(Model.tempLevel(90), 'hot');
  assert.equal(Model.tempLevel(null), 'ok');
});

test('pendingReboot reads the flag', () => {
  const s = Model.parseProbe(FIXTURE);
  assert.equal(Model.pendingReboot(s), false);
  const s2 = Model.parseProbe(FIXTURE.replace('"pending_reboot","display":"pending_reboot","current":"0"', '"pending_reboot","display":"pending_reboot","current":"1"'));
  assert.equal(Model.pendingReboot(s2), true);
});

test('validWrite gates helper verbs strictly', () => {
  assert.equal(Model.validWrite('charge-mode', 1), true);
  assert.equal(Model.validWrite('charge-mode', 3), false);
  assert.equal(Model.validWrite('charge-mode', '1'), true);
  assert.equal(Model.validWrite('charge-limit', 80), true);
  assert.equal(Model.validWrite('charge-limit', 10), false);
  assert.equal(Model.validWrite('charge-limit', 101), false);
  assert.equal(Model.validWrite('fan-mode', 0), true);
  assert.equal(Model.validWrite('fan-mode', 2), false);
  assert.equal(Model.validWrite('fan-point', 50, 3, 'temp'), true);
  assert.equal(Model.validWrite('fan-point', 150, 3, 'temp'), false);
  assert.equal(Model.validWrite('fan-point', 140, 9, 'pwm'), false);
  assert.equal(Model.validWrite('fan-point', 140, 3, 'rpm'), false);
  assert.equal(Model.validWrite('rm-rf', 1), false);
});

test('identity and fan strings', () => {
  const s = Model.parseProbe(FIXTURE);
  assert.deepEqual(Model.identityLines(s),
    ['ASUS Vivobook S 16 (M5606WA)', 'BIOS M5606WA.316']);
  assert.equal(Model.fanString(3600), '3600 rpm');
  assert.equal(Model.fanString(0), 'idle');
});
