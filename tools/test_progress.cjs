const { test } = require('node:test');
const assert = require('node:assert/strict');
const api = require('../web/progress.js');
function storage(initial = {}) {
  const data = new Map(Object.entries(initial));
  return { get length() { return data.size; }, key: i => [...data.keys()][i], getItem: key => data.get(key) ?? null,
    setItem: (key, value) => data.set(key, value), removeItem: key => data.delete(key) };
}
const choice = 'o-0123456789abcdef', revision = '0123456789abcdef';
const question = { id: 'TFA-001-Q1', revision, answer: choice, options: [{ id: choice, text: 'Yes' }, { id: 'o-fedcba9876543210', text: 'No' }] };
test('malformed roots, nested answers and truthy strings normalize safely', () => {
  for (const value of [null, 5, 'bad', [], { 'TFA-001': null }, { 'TFA-001': 'bad' }]) assert.doesNotThrow(() => api.normalize(value));
  for (const answers of ['bad', 1, [], null, { unknown: true }]) {
    const state = api.normalize({ 'TFA-001': { lesson: 'false', answers }, 'TFA-999': {} });
    assert.equal(state['TFA-001'].lesson, false); assert.deepEqual(state['TFA-001'].answers, {}); assert.equal(state['TFA-999'], undefined);
  }
});
test('two tabs retain edits to different lessons and fields', () => {
  const disk = storage(); const a = api.createStore({ storage: disk }), b = api.createStore({ storage: disk });
  a.set('TFA-001', 'lesson', true); b.set('TFA-002', 'lesson', true); b.set('TFA-001', 'cleanup', true);
  assert.equal(a.get('TFA-001').lesson, true); assert.equal(a.get('TFA-001').cleanup, true); assert.equal(a.get('TFA-002').lesson, true);
});
test('reset cannot resurrect old fields from another tab', () => {
  const disk = storage(); const a = api.createStore({ storage: disk }), b = api.createStore({ storage: disk });
  a.set('TFA-001', 'lesson', true); b.reset(); a.set('TFA-002', 'exercise', true);
  assert.equal(b.get('TFA-001').lesson, false); assert.equal(b.get('TFA-002').exercise, true);
});
test('storage events notify subscribers; unrelated keys do not', () => {
  let listener, calls = 0;
  const store = api.createStore({ storage: storage(), listen: fn => { listener = fn; } });
  store.subscribe(() => calls++); listener({ key: 'other' }); assert.equal(calls, 0);
  listener({ key: api.PREFIX + 'generation' }); assert.equal(calls, 1);
});
test('legacy migration preserves flags, drops unverifiable scores and explains it', () => {
  const statuses = []; const disk = storage({ [api.LEGACY]: JSON.stringify({ 'TFA-001': { lesson: true, answers: { 'TFA-001-Q1': true } } }) });
  const store = api.createStore({ storage: disk, onStatus: s => statuses.push(s) });
  assert.equal(store.get('TFA-001').lesson, true); assert.deepEqual(store.get('TFA-001').answers, {}); assert.ok(statuses.includes('migrated'));
  assert.equal(store.export().legacyQuizArchive['TFA-001'].answers['TFA-001-Q1'], true);
});
test('blocked storage remains usable and exportable in session', () => {
  const statuses = []; const store = api.createStore({ storage: null, onStatus: s => statuses.push(s) });
  store.set('TFA-001', 'lesson', true); store.set('TFA-001', question.id, { choice, revision });
  assert.equal(store.export().labs['TFA-001'].lesson, true); assert.equal(api.score(store.get('TFA-001'), [question]), 1); assert.ok(statuses.includes('session'));
});
test('quota failure keeps existing progress and the new edit in memory', () => {
  const disk = storage(); const first = api.createStore({ storage: disk }); first.set('TFA-001', 'lesson', true);
  disk.setItem = () => { throw Error('QuotaExceededError'); };
  const store = api.createStore({ storage: disk }); store.set('TFA-002', 'cleanup', true);
  assert.equal(store.get('TFA-001').lesson, true); assert.equal(store.get('TFA-002').cleanup, true);
});
test('score checks current identities and revisions only', () => {
  const entry = { answers: { [question.id]: { choice, revision }, extra: { choice, revision } } };
  assert.equal(api.score(entry, [question]), 1);
  assert.equal(api.score(entry, [{ ...question, revision: 'fedcba9876543210' }]), 0);
  assert.deepEqual(api.optionOrder(question), api.optionOrder({ ...question, options: [...question.options].reverse() }));
});
test('export/import round trip and merge/replace semantics', () => {
  const source = api.createStore({ storage: storage() }); source.set('TFA-001', 'lesson', true); source.set('TFA-001', question.id, { choice, revision });
  const parsed = api.parseImport(JSON.stringify(source.export()), { 'TFA-001': [question] });
  const dest = api.createStore({ storage: storage() }); dest.set('TFA-002', 'cleanup', true); dest.applyImport(parsed, 'merge');
  assert.equal(dest.get('TFA-001').lesson, true); assert.equal(dest.get('TFA-002').cleanup, true);
  dest.applyImport(parsed, 'replace'); assert.equal(dest.get('TFA-002').cleanup, false); assert.deepEqual(dest.get('TFA-001'), source.get('TFA-001'));
});
test('invalid imports reject before touching saved progress', () => {
  const store = api.createStore({ storage: storage() }); store.set('TFA-001', 'lesson', true);
  const valid = store.export();
  for (const data of ['{bad', JSON.stringify({ ...valid, schemaVersion: 99 }), JSON.stringify({ ...valid, labs: { 'TFA-999': {} } }), JSON.stringify({ ...valid, labs: { 'TFA-001': { lesson: true, exercise: false, cleanup: false, answers: { [question.id]: { choice, revision: 'fedcba9876543210' } } } } })]) {
    assert.throws(() => api.parseImport(data, { 'TFA-001': [question] })); assert.equal(store.get('TFA-001').lesson, true);
  }
});
