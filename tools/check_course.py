"""Validate course metadata, original question banks, local links and source assets."""
from pathlib import Path
from urllib.parse import urlparse, unquote
import json
import re
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
EXCLUDED={'.site-docs','site','.terraform','.git','.venv','work','node_modules','playwright-report','test-results'}

def main():
    errors=[]
    catalog=json.loads((ROOT/'curriculum/labs.json').read_text(encoding='utf-8'))
    labs=catalog['labs']
    if [l['id'] for l in labs] != [f'TFA-{i:03}' for i in range(1,41)]: errors.append('Catalog must contain 40 ordered, unique lab IDs.')
    known={l['id'] for l in labs}; prompts=set(); count=0
    for l in labs:
        folder=ROOT/l['path']; readme=folder/'README.md'
        if not readme.exists(): errors.append(f'{l["id"]}: missing README');continue
        if len(readme.read_text(encoding='utf-8').split())<350:errors.append(f'{l["id"]}: lesson is too short for a complete guided exercise')
        for dep in l['prerequisites']:
            if dep not in known or dep>=l['id']: errors.append(f'{l["id"]}: invalid prerequisite {dep}')
        if not (ROOT/l['diagram']).exists():errors.append(f'{l["id"]}: missing diagram')
        try:q=json.loads((ROOT/l['quiz']).read_text(encoding='utf-8'))
        except Exception as e:errors.append(f'{l["id"]}: unreadable quiz: {e}');continue
        if len(q)!=5:errors.append(f'{l["id"]}: expected five questions')
        for i,item in enumerate(q,1):
            count+=1
            if item.get('id')!=f'{l["id"]}-Q{i}':errors.append(f'{l["id"]}: invalid question ID at {i}')
            if len(item.get('options',[]))!=4 or len(set(item.get('options',[])))!=4:errors.append(f'{l["id"]} Q{i}: four distinct options required')
            if type(item.get('answer')) is not int or not 0<=item['answer']<4:errors.append(f'{l["id"]} Q{i}: answer must be zero-based index')
            if len(item.get('explanation','').split())<4:errors.append(f'{l["id"]} Q{i}: explanation is too short')
            prompt=item.get('prompt','').strip().casefold()
            if not prompt or prompt in prompts: errors.append(f'{l["id"]} Q{i}: empty or duplicate prompt')
            prompts.add(prompt)
        if not list(folder.glob('*.tf')):errors.append(f'{l["id"]}: missing executable Terraform example')
    for path in ROOT.rglob('*.svg'):
        if EXCLUDED.intersection(path.parts):continue
        try:ET.parse(path)
        except ET.ParseError as e:errors.append(f'{path.relative_to(ROOT)}: invalid SVG {e}')
    for path in ROOT.rglob('*.md'):
        if EXCLUDED.intersection(path.parts):continue
        body=re.sub(r'```.*?```','',path.read_text(encoding='utf-8'),flags=re.S)
        for href in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)\)',body):
            if urlparse(href).scheme or href.startswith(('#','//')):continue
            raw=unquote(href.split('#')[0])
            target=(path.parent/raw).resolve()
            if raw and not target.exists():errors.append(f'{path.relative_to(ROOT)}: broken link {href}')
    if count!=200: errors.append(f'Expected 200 questions, found {count}')
    for error in errors:print('FAIL '+error)
    if errors:raise SystemExit(1)
    print(f'PASS: 40 lessons, 200 unique questions, prerequisites, diagrams and local Markdown links.')

if __name__=='__main__':main()
