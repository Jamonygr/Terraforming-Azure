/* One storage key per field prevents lost updates between tabs. A generation
 * key isolates resets/replacements from old tab state. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TFAProgress = api;
})(typeof window === 'undefined' ? globalThis : window, function () {
  'use strict';
  const PREFIX = 'terraforming-azure-progress-v2:';
  const LEGACY = 'terraforming-azure-progress-v1';
  const FLAGS = ['lesson', 'exercise', 'cleanup'];
  const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const labId = id => /^TFA-\d{3}$/.test(id) && Number(id.slice(4)) >= 1 && Number(id.slice(4)) <= 40;
  const answerId = (lab, id) => new RegExp(`^${lab}-Q[1-5]$`).test(id);
  const answer = value => object(value) && typeof value.choice === 'string' && typeof value.revision === 'string' && /^o-[a-f0-9]{16}$/.test(value.choice) && /^[a-f0-9]{16}$/.test(value.revision);
  const empty = () => ({ lesson: false, exercise: false, cleanup: false, answers: {} });
  function normalize(input) {
    const labs = {};
    if (!object(input)) return labs;
    for (const [id, value] of Object.entries(input)) {
      if (!labId(id) || !object(value)) continue;
      const entry = empty();
      FLAGS.forEach(key => { entry[key] = value[key] === true; });
      if (object(value.answers)) for (const [qid, record] of Object.entries(value.answers)) {
        if (answerId(id, qid) && answer(record)) entry.answers[qid] = { choice: record.choice, revision: record.revision };
      }
      labs[id] = entry;
    }
    return labs;
  }
  function legacyScores(input) {
    const result = {};
    if (!object(input)) return result;
    for (const [id, entry] of Object.entries(input)) {
      if (!labId(id) || !object(entry) || !object(entry.answers)) continue;
      const records = Object.fromEntries(Object.entries(entry.answers).filter(([qid, value]) => answerId(id, qid) && typeof value === 'boolean'));
      if (Object.keys(records).length) result[id] = { answers: records };
    }
    return result;
  }
  function parseImport(text, registry) {
    if (text.length > 1024 * 1024) throw Error('Choose a progress file smaller than 1 MB.');
    let data;
    try { data = JSON.parse(text); } catch { throw Error('This file is not valid JSON. Your progress has not changed.'); }
    if (!object(data) || data.schemaVersion !== 2 || data.course !== 'terraforming-azure' || !object(data.labs)) {
      throw Error('Choose an exported Terraforming Azure version 2 progress file. Your progress has not changed.');
    }
    for (const [id, entry] of Object.entries(data.labs)) {
      if (!Object.hasOwn(registry, id) || !object(entry)) throw Error(`Unknown or invalid lesson: ${id}`);
      if (FLAGS.some(key => typeof entry[key] !== 'boolean') || !object(entry.answers)) throw Error(`Invalid completion fields in ${id}.`);
      if (Object.keys(entry).some(key => ![...FLAGS, 'answers'].includes(key))) throw Error(`Unknown field in ${id}.`);
      for (const [qid, record] of Object.entries(entry.answers)) {
        const question = registry[id].find(q => q.id === qid);
        if (!question || !answer(record) || record.revision !== question.revision || !question.options.some(o => o.id === record.choice)) {
          throw Error(`Invalid or outdated answer ${qid}. Export a current file or remove this answer before importing.`);
        }
      }
    }
    return normalize(data.labs);
  }
  function score(entry, questions) {
    return questions.filter(q => {
      const record = entry?.answers?.[q.id];
      return record?.revision === q.revision && record.choice === q.answer;
    }).length;
  }
  function optionOrder(question) {
    const hash = text => [...text].reduce((h, c) => Math.imul(h ^ c.charCodeAt(0), 16777619) >>> 0, 2166136261);
    return [...question.options].sort((a, b) => hash(question.id + a.id) - hash(question.id + b.id) || a.id.localeCompare(b.id));
  }
  function createStore({ storage, listen = () => {}, onStatus = () => {} }) {
    let memory = {}, archive = {}, available = Boolean(storage), generation = 'initial', suspended = false;
    const subscribers = new Set();
    const notify = () => { if (!suspended) subscribers.forEach(fn => fn()); };
    const fail = () => { if (available) { available = false; onStatus('session'); } };
    function epoch() { return storage.getItem(PREFIX + 'generation') || 'initial'; }
    function snapshot() {
      if (!available) return normalize(memory);
      try {
        generation = epoch();
        try { archive = legacyScores(JSON.parse(storage.getItem(PREFIX + 'legacy-archive') || '{}')); } catch { archive = {}; }
        const prefix = PREFIX + generation + ':';
        const labs = {};
        for (let i = 0; i < storage.length; i++) {
          const key = storage.key(i);
          if (!key?.startsWith(prefix)) continue;
          const [id, field] = key.slice(prefix.length).split(':');
          if (!labId(id) || (!FLAGS.includes(field) && !answerId(id, field))) continue;
          let value;
          try { value = JSON.parse(storage.getItem(key)); } catch { continue; }
          const entry = labs[id] ||= empty();
          if (FLAGS.includes(field)) entry[field] = value === true;
          else if (answer(value)) entry.answers[field] = value;
        }
        memory = normalize(labs);
      } catch { fail(); }
      return normalize(memory);
    }
    function set(id, field, value) {
      if (!labId(id) || (!FLAGS.includes(field) && !answerId(id, field))) throw Error('Invalid progress field.');
      if (FLAGS.includes(field) ? typeof value !== 'boolean' : value !== null && !answer(value)) throw Error('Invalid progress value.');
      const latest = snapshot(); const entry = latest[id] ||= empty();
      if (FLAGS.includes(field)) entry[field] = value;
      else if (value === null) delete entry.answers[field];
      else entry.answers[field] = value;
      memory = latest;
      if (available) try {
        const key = PREFIX + epoch() + ':' + id + ':' + field;
        if (value === null) storage.removeItem(key); else storage.setItem(key, JSON.stringify(value));
      } catch { fail(); }
      notify();
    }
    function reset() {
      memory = {}; archive = {};
      if (available) try {
        generation = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        storage.setItem(PREFIX + 'generation', generation);
        const obsolete = [];
        for (let i = 0; i < storage.length; i++) {
          const key = storage.key(i);
          if (key?.startsWith(PREFIX) && key !== PREFIX + 'generation' && !key.startsWith(PREFIX + generation + ':')) obsolete.push(key);
        }
        obsolete.forEach(key => storage.removeItem(key)); storage.removeItem(LEGACY);
      } catch { fail(); }
      notify();
    }
    function applyImport(labs, mode) {
      if (!['merge', 'replace'].includes(mode)) throw Error('Invalid import mode.');
      suspended = true;
      try {
        if (mode === 'replace') reset();
        const current = snapshot();
        for (const [id, entry] of Object.entries(normalize(labs))) {
          FLAGS.forEach(key => set(id, key, mode === 'merge' ? entry[key] || current[id]?.[key] === true : entry[key]));
          Object.entries(entry.answers).forEach(([qid, record]) => {
            if (mode === 'replace' || !current[id]?.answers?.[qid] || current[id].answers[qid].revision !== record.revision) set(id, qid, record);
          });
        }
      } finally { suspended = false; notify(); }
    }
    // Old boolean-only quiz scores cannot identify a choice after editorial
    // revisions. Preserve completion and explain why quizzes need a new attempt.
    if (available) try {
      if (!storage.getItem(PREFIX + 'generation') && storage.getItem(LEGACY)) {
        let old;
        try { old = JSON.parse(storage.getItem(LEGACY)); } catch { old = {}; }
        const migrated = normalize(old); archive = legacyScores(old);
        memory = migrated;
        storage.setItem(PREFIX + 'legacy-archive', JSON.stringify(archive));
        storage.setItem(PREFIX + 'generation', 'initial');
        Object.entries(migrated).forEach(([id, entry]) => FLAGS.forEach(key => storage.setItem(PREFIX + 'initial:' + id + ':' + key, JSON.stringify(entry[key]))));
        storage.removeItem(LEGACY); onStatus('migrated');
      }
      try { archive = legacyScores(JSON.parse(storage.getItem(PREFIX + 'legacy-archive') || '{}')); } catch { archive = {}; }
      snapshot();
      storage.setItem(PREFIX + 'probe', '1'); storage.removeItem(PREFIX + 'probe');
    } catch { fail(); }
    if (!available) onStatus('session');
    listen(event => { if (event.key === null || event.key?.startsWith(PREFIX)) { snapshot(); notify(); } });
    return { snapshot, set, reset, applyImport, get: id => snapshot()[id] || empty(),
      subscribe: fn => { subscribers.add(fn); return () => subscribers.delete(fn); },
      export: () => ({ schemaVersion: 2, course: 'terraforming-azure', exportedAt: new Date().toISOString(), labs: snapshot(), legacyQuizArchive: archive }) };
  }
  return { PREFIX, LEGACY, FLAGS, normalize, parseImport, score, optionOrder, createStore };
});
