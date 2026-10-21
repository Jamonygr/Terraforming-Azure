// Regression checks for recoverable browser-local progress; no browser/cloud needed.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../web/course.js'),'utf8');
const element=()=>({dataset:{lab:'TFA-001'},append(){},addEventListener(){},setAttribute(){},replaceChildren(){}});
for(const stored of ['null','5','"bad"','[]','{invalid','{"TFA-001":null}','{"TFA-001":"bad"}','{}']) {
  const completion=element();
  const document={currentScript:{src:'https://example.test/course/web/course.js'},
    querySelectorAll:selector=>selector==='.course-completion'?[completion]:[],
    querySelector:()=>null,createElement:element,createTextNode:text=>({textContent:text})};
  assert.doesNotThrow(()=>vm.runInNewContext(source,{document,URL,localStorage:{getItem:()=>stored,setItem(){}},
    fetch:()=>Promise.resolve({ok:true,json:()=>Promise.resolve({labs:[]})})}),`stored progress ${stored}`);
}
console.log('PASS: malformed JSON, invalid root types and invalid lab entries recover without breaking controls.');
