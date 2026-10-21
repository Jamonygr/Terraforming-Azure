(() => {
  'use strict';
  const api = window.TFAProgress;
  const webBase = new URL('.', document.currentScript.src);
  const el = (tag, text = '', props = {}) => Object.assign(document.createElement(tag), { textContent: text, ...props });
  const article = document.querySelector('article') || document.body;
  const notice = el('div', '', { className: 'tfa-notice', hidden: true });
  notice.setAttribute('role', 'status'); article.prepend(notice);
  let storage;
  try { storage = window.localStorage; } catch { storage = null; }
  const store = api.createStore({ storage, listen: fn => window.addEventListener('storage', fn), onStatus: status => {
    notice.hidden = false;
    notice.textContent = status === 'session'
      ? 'Session only: this browser cannot save progress. Keep this tab open and export your progress before leaving.'
      : 'Your earlier lesson, exercise and cleanup marks were preserved. Earlier quiz scores are archived in exports; please retry quizzes to record selected answers for the current questions.';
    if (status === 'session') {
      const backup = el('button', 'Export session progress', { type: 'button', className: 'tfa-button' });
      backup.addEventListener('click', () => download(store.export())); notice.append(backup);
    }
  }});
  function download(data) {
    const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
    const a = el('a', '', { href: url, download: 'terraforming-azure-progress.json' }); a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  const button = (text, fn) => { const b = el('button', text, { type: 'button', className: 'tfa-button' }); b.addEventListener('click', fn); return b; };
  function load(name, success, host) {
    const failure = el('div', '', { className: 'tfa-notice', hidden: true });
    failure.setAttribute('role', 'status'); host.append(failure);
    const retry = async () => {
      failure.hidden = true;
      try {
        const response = await fetch(new URL(name, webBase));
        if (!response.ok) throw Error('HTTP ' + response.status);
        success(await response.json());
      } catch {
        failure.replaceChildren(el('p', `Could not load ${name === 'quizzes.json' ? 'questions' : 'the lesson catalog'}. Your saved progress is safe.`), button('Retry loading', retry));
        failure.hidden = false;
      }
    };
    retry();
  }
  function renderQuiz(container, lab, questions) {
    container._unsubscribe?.(); container.replaceChildren(); container.dataset.lab = lab;
    const updates = [];
    questions.forEach((q, i) => {
      const field = el('fieldset', '', { className: 'quiz-question' }); field.dataset.question = q.id;
      field.append(el('legend', `${i + 1}. ${q.prompt}`));
      const radios = [];
      api.optionOrder(q).forEach(option => {
        const label = el('label'); const input = el('input', '', { type: 'radio', name: `${lab}-${q.id}`, value: option.id });
        radios.push(input); label.append(input, el('span', option.text)); field.append(label);
      });
      const feedback = el('div', '', { className: 'quiz-feedback', hidden: true }); feedback.setAttribute('aria-live', 'polite');
      const explain = choice => `${choice === q.answer ? 'Correct.' : 'Try again.'} ${q.explanation}`;
      const check = button('Check answer', () => {
        const selected = radios.find(input => input.checked);
        if (!selected) { feedback.hidden = false; feedback.textContent = 'Choose an answer first.'; radios[0].focus(); return; }
        store.set(lab, q.id, { choice: selected.value, revision: q.revision });
      });
      let previous;
      updates.push(() => {
        const record = store.get(lab).answers[q.id]; const serialized = JSON.stringify(record);
        if (serialized === previous) return; previous = serialized;
        const valid = record?.revision === q.revision && q.options.some(o => o.id === record.choice);
        radios.forEach(input => { input.checked = Boolean(valid && input.value === record.choice); });
        feedback.hidden = !record;
        feedback.textContent = valid ? explain(record.choice) : record ? 'This question has changed. Choose and check a new answer.' : '';
      });
      field.append(check, feedback); container.append(field);
    });
    container.append(button('Reset this quiz', () => {
      container.querySelectorAll('input').forEach(input => { input.checked = false; });
      container.querySelectorAll('.quiz-feedback').forEach(feedback => { feedback.hidden = true; });
      questions.forEach(q => store.set(lab, q.id, null));
    }));
    const update = () => updates.forEach(fn => fn()); update(); container._unsubscribe = store.subscribe(update);
  }
  document.querySelectorAll('.course-completion').forEach(container => {
    const lab = container.dataset.lab; container.append(el('h3', 'Record your progress'));
    [['lesson', 'I understand the lesson'], ['exercise', 'I completed the exercise'], ['cleanup', 'I verified cleanup / no Azure resources were created']].forEach(([key, text]) => {
      const label = el('label'); const input = el('input', '', { type: 'checkbox' });
      input.addEventListener('change', () => store.set(lab, key, input.checked));
      const update = () => { input.checked = store.get(lab)[key]; }; update(); store.subscribe(update);
      label.append(input, document.createTextNode(' ' + text)); container.append(label);
    });
  });
  const progress = document.querySelector('#course-progress'); const practice = document.querySelector('#practice-lab');
  let catalog, quizzes, pendingImport;
  const summary = el('div'); const rows = el('div');
  function renderProgress() {
    if (!progress || !catalog) return;
    const state = store.snapshot(); const done = catalog.labs.filter(l => state[l.id]?.lesson).length;
    const meter = el('progress', '', { max: catalog.labs.length, value: done }); meter.setAttribute('aria-label', 'Lessons understood');
    summary.replaceChildren(el('p', `${done} of ${catalog.labs.length} lessons marked understood.`), meter); rows.replaceChildren();
    catalog.labs.forEach(l => {
      const entry = state[l.id] || {}; const row = el('div', '', { className: 'progress-row' }); row.dataset.lab = l.id;
      const link = el('a', l.id, { href: new URL(`../labs/${l.id}/`, webBase).href }); const info = el('div', l.title);
      const score = quizzes ? `${api.score(entry, quizzes[l.id])}/${quizzes[l.id].length}` : 'questions unavailable';
      info.append(el('small', `Lesson: ${entry.lesson ? 'done' : 'pending'} · Exercise: ${entry.exercise ? 'done' : 'pending'} · Cleanup: ${entry.cleanup ? 'done' : 'pending'} · Quiz: ${score}`));
      row.append(link, info); rows.append(row);
    });
  }
  const importStatus = el('div', '', { className: 'tfa-notice', hidden: true }); importStatus.setAttribute('role', 'status');
  const importPreview = el('div', '', { hidden: true });
  importPreview.setAttribute('aria-live', 'polite');
  const importInput = el('input', '', { type: 'file', accept: '.json,application/json', id: 'progress-file', disabled: true });
  if (progress) {
    progress.append(summary, rows);
    const exportButton = button('Export progress', () => {
      const data = store.export();
      // Discard obsolete answer revisions from exports; completion survives.
      if (quizzes) for (const [lab, entry] of Object.entries(data.labs)) for (const [qid, record] of Object.entries(entry.answers)) {
        const q = quizzes[lab]?.find(item => item.id === qid);
        if (!q || q.revision !== record.revision) delete entry.answers[qid];
      }
      download(data);
    });
    const reset = button('Reset this browser’s progress', () => { if (confirm('Remove all saved progress from this browser and its open course tabs?')) store.reset(); });
    const label = el('label', 'Choose a progress file to preview', { htmlFor: 'progress-file' });
    const mode = el('select', '', { id: 'import-mode' });
    mode.append(el('option', 'Merge: keep current marks and answers', { value: 'merge' }), el('option', 'Replace: use only the imported progress', { value: 'replace' }));
    const apply = button('Import previewed progress', () => {
      if (!pendingImport) return;
      store.applyImport(pendingImport, mode.value); pendingImport = null; importPreview.hidden = true; importInput.value = '';
      importStatus.hidden = false; importStatus.textContent = 'Progress imported.';
    });
    importInput.addEventListener('change', async () => {
      pendingImport = null; importPreview.hidden = true; importStatus.hidden = true;
      const file = importInput.files[0]; if (!file) return;
      try {
        if (file.size > 1024 * 1024) throw Error('Choose a progress file smaller than 1 MB.');
        pendingImport = api.parseImport(await file.text(), quizzes);
        const entries = Object.values(pendingImport);
        importPreview.replaceChildren(el('p', `Preview: ${entries.filter(e => e.lesson).length} lessons understood, ${entries.filter(e => e.exercise).length} exercises, ${entries.filter(e => e.cleanup).length} cleanup marks and ${entries.reduce((n, e) => n + Object.keys(e.answers).length, 0)} checked answers. No changes have been made.`), el('label', 'Import method', { htmlFor: 'import-mode' }), mode, apply);
        importPreview.hidden = false;
      } catch (error) { importStatus.hidden = false; importStatus.textContent = error.message; }
    });
    progress.append(exportButton, reset, el('h2', 'Restore progress'), el('p', 'Import becomes available when current questions load. Merge keeps your current completion marks and answers, filling gaps from the file. Replace resets this browser’s progress first.'), label, importInput, importStatus, importPreview);
    store.subscribe(renderProgress);
  }
  const renderPractice = () => { if (practice && quizzes && catalog) renderQuiz(document.querySelector('#practice-quiz'), practice.value, quizzes[practice.value]); };
  if (practice || progress) load('catalog.json', data => {
    catalog = data;
    if (practice) { practice.replaceChildren(...catalog.labs.map(l => el('option', `${l.id} · ${l.title}`, { value: l.id }))); practice.disabled = false; renderPractice(); }
    renderProgress();
  }, practice?.parentElement || progress);
  if (practice) { practice.disabled = true; practice.addEventListener('change', renderPractice); }
  const lessonQuizzes = document.querySelectorAll('.course-quiz[data-lab]');
  if (practice || progress || lessonQuizzes.length) load('quizzes.json', data => {
    quizzes = data; lessonQuizzes.forEach(container => renderQuiz(container, container.dataset.lab, quizzes[container.dataset.lab]));
    renderPractice(); renderProgress(); importInput.disabled = false;
  }, document.querySelector('#practice-quiz') || progress || lessonQuizzes[0].parentElement);
})();
