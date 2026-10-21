(() => {
  'use strict';
  const STORE='terraforming-azure-progress-v1';
  const script = document.currentScript;
  const webBase = new URL('.', script.src);
  let state={};
  const object=value=>value!==null && typeof value==='object' && !Array.isArray(value);
  try {const parsed=JSON.parse(localStorage.getItem(STORE)||'{}');state=object(parsed)?parsed:{};} catch {state={};}
  const save=()=>{try{localStorage.setItem(STORE,JSON.stringify(state));}catch{/* Private browsing can disable storage. */}};
  const el=(tag,text,props={})=>Object.assign(document.createElement(tag),{textContent:text,...props});
  const read=lab=>{if(!object(state[lab]))state[lab]={lesson:false,exercise:false,cleanup:false};return state[lab];};
  const quizData=fetch(new URL('quizzes.json',webBase)).then(r=>{if(!r.ok)throw Error('quiz data');return r.json();});
  const catalogData=fetch(new URL('catalog.json',webBase)).then(r=>{if(!r.ok)throw Error('catalog');return r.json();});
  function renderQuiz(container,lab,questions) {
    container.replaceChildren();
    container.dataset.lab=lab;
    questions.forEach((q,i)=>{
      const field=el('fieldset','',{className:'quiz-question'});
      field.append(el('legend',`${i+1}. ${q.prompt}`));
      q.options.forEach((option,n)=>{
        const label=el('label','');
        const input=el('input','',{type:'radio',name:`${lab}-${q.id}`,value:String(n)});
        label.append(input,el('span',option));field.append(label);
      });
      const feedback=el('div','',{className:'quiz-feedback',hidden:true});
      feedback.setAttribute('aria-live','polite');
      const check=el('button','Check answer',{className:'tfa-button',type:'button'});
      check.addEventListener('click',()=>{
        const selected=field.querySelector('input:checked');
        feedback.hidden=false;
        if(!selected){feedback.textContent='Choose an answer first.';return;}
        const correct=Number(selected.value)===q.answer;
        feedback.textContent=`${correct?'Correct.':'Try again.'} ${q.explanation}`;
        const entry=read(lab);entry.answers ||= {};entry.answers[q.id]=correct;save();
      });
      field.append(check,feedback);container.append(field);
    });
  }
  document.querySelectorAll('.course-completion').forEach(container=>{
    const lab=container.dataset.lab;const entry=read(lab);
    container.append(el('h3','Record your progress'));
    [['lesson','I understand the lesson'],['exercise','I completed the exercise'],['cleanup','I verified cleanup / no Azure resources were created']].forEach(([key,text])=>{
      const label=el('label','');const input=el('input','',{type:'checkbox',checked:!!entry[key]});
      input.addEventListener('change',()=>{entry[key]=input.checked;save();});label.append(input,document.createTextNode(' '+text));container.append(label);
    });
  });
  Promise.all([quizData,catalogData]).then(([quizzes,catalog])=>{
    document.querySelectorAll('.course-quiz[data-lab]').forEach(c=>renderQuiz(c,c.dataset.lab,quizzes[c.dataset.lab]));
    const select=document.querySelector('#practice-lab');
    if(select){
      catalog.labs.forEach(l=>select.append(el('option',`${l.id} · ${l.title}`,{value:l.id})));
      const render=()=>renderQuiz(document.querySelector('#practice-quiz'),select.value,quizzes[select.value]);
      select.addEventListener('change',render);render();
    }
    const progress=document.querySelector('#course-progress');
    if(progress){
      const done=catalog.labs.filter(l=>read(l.id).lesson).length;
      progress.append(el('p',`${done} of ${catalog.labs.length} lessons marked understood.`));
      const meter=el('progress','',{max:catalog.labs.length,value:done});meter.setAttribute('aria-label','Lessons understood');progress.append(meter);
      catalog.labs.forEach(l=>{
        const row=el('div','',{className:'progress-row'});const entry=read(l.id);
        const link=el('a',l.id,{href:new URL(`../labs/${l.id}/`,webBase).href});
        const info=el('div',l.title);const score=Object.values(entry.answers||{}).filter(Boolean).length;
        info.append(el('small',`Lesson: ${entry.lesson?'done':'pending'} · Exercise: ${entry.exercise?'done':'pending'} · Cleanup: ${entry.cleanup?'done':'pending'} · Quiz: ${score}/5`));row.append(link,info);progress.append(row);
      });
      const exportButton=el('button','Export progress',{className:'tfa-button',type:'button'});
      exportButton.addEventListener('click',()=>{const url=URL.createObjectURL(new Blob([JSON.stringify(state,null,2)],{type:'application/json'}));const a=el('a','',{href:url,download:'terraforming-azure-progress.json'});a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
      const reset=el('button','Reset this browser’s progress',{className:'tfa-button',type:'button'});
      reset.addEventListener('click',()=>{if(confirm('Remove all saved progress from this browser?')){state={};save();location.reload();}});
      progress.append(exportButton,reset);
    }
  }).catch(()=>document.querySelectorAll('.course-quiz,#course-progress').forEach(c=>c.append(el('p','Learning data could not load. Refresh this page; use the repository quiz.json files if you are offline.'))));
})();
