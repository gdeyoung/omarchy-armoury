// GPU-mode logic with synthetic dGPU-machine fixtures (this M5606WA has no
// dgpu_disable/gpu_mux_mode attributes — real fixture asserts the iGPU case).
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

function withAttrs(extra) {
  const s = Model.parseProbe(FIXTURE);
  for (const k in extra) s.attrs[k] = extra[k];
  if (!s.attrOrder.includes(extra && Object.keys(extra)[0]))
    s.attrOrder = s.attrOrder.concat(Object.keys(extra));
  return s;
}

test('iGPU-only machine (real fixture): no GPU section', () => {
  const s = Model.parseProbe(FIXTURE);
  assert.equal(Model.gpuCapability(s).switchable, false);
  assert.deepEqual(Model.gpuOptions(s), []);
  assert.equal(Model.gpuMode(s), null);
});

test('full dGPU machine: three modes, hybrid default', () => {
  const s = withAttrs({
    dgpu_disable: { display: 'dGPU', current: '0', possible: ['0','1'], type: 'enumeration' },
    gpu_mux_mode: { display: 'GPU MUX', current: '0', possible: ['0','1'], type: 'enumeration' }
  });
  assert.equal(Model.gpuCapability(s).switchable, true);
  assert.deepEqual(Model.gpuOptions(s).map(m => m.key), ['hybrid', 'integrated', 'ultimate']);
  assert.equal(Model.gpuMode(s), 'hybrid');
});

test('Eco (dgpu_disable=1) reads as integrated', () => {
  const s = withAttrs({
    dgpu_disable: { display: 'dGPU', current: '1', possible: ['0','1'], type: 'enumeration' }
  });
  assert.equal(Model.gpuMode(s), 'integrated');
  assert.deepEqual(Model.gpuOptions(s).map(m => m.key), ['hybrid', 'integrated']);
});

test('mux=1 reads as ultimate, even with dgpu enabled', () => {
  const s = withAttrs({
    dgpu_disable: { display: 'dGPU', current: '0', possible: ['0','1'], type: 'enumeration' },
    gpu_mux_mode: { display: 'GPU MUX', current: '1', possible: ['0','1'], type: 'enumeration' }
  });
  assert.equal(Model.gpuMode(s), 'ultimate');
});

test('mux-only machine (no dgpu_disable attr) still offers hybrid + ultimate', () => {
  const s = withAttrs({
    gpu_mux_mode: { display: 'GPU MUX', current: '0', possible: ['0','1'], type: 'enumeration' }
  });
  const opts = Model.gpuOptions(s).map(m => m.key);
  assert.deepEqual(opts, ['hybrid', 'ultimate']);
  assert.equal(Model.gpuMode(s), 'hybrid');
});

test('gpuWrites returns the attribute writes per mode', () => {
  assert.deepEqual(Model.gpuWrites('integrated'), [{ verb: 'gpu-disable', value: 1 }]);
  assert.deepEqual(Model.gpuWrites('ultimate'), [{ verb: 'gpu-mux', value: 1 }]);
  assert.deepEqual(Model.gpuWrites('bogus'), []);
});

test('validWrite accepts the GPU verbs', () => {
  assert.equal(Model.validWrite('gpu-disable', 1), true);
  assert.equal(Model.validWrite('gpu-disable', 2), false);
  assert.equal(Model.validWrite('gpu-mux', 0), true);
  assert.equal(Model.validWrite('gpu-mux', '1'), true);
});
