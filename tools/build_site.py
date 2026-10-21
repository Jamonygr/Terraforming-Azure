"""Build the MkDocs source tree from the authoritative repository lessons."""
from pathlib import Path
import sys
if sys.version_info < (3,12):
    raise SystemExit('Website tooling requires Python 3.12+. On Windows use py -3.12 tools/build_site.py.')
import html
import json
import re
import shutil
import os
from urllib.parse import urlparse, unquote
import yaml

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.site-docs'
BASE = 'https://github.com/Jamonygr/Terraforming-Azure/blob/main/'

def write(path, content):
    target = OUT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')

def mapped(source):
    rel = source.relative_to(ROOT).as_posix()
    match = re.fullmatch(r'labs/(TFA-\d{3})/README.md', rel)
    if match:
        return Path('labs') / (match[1] + '.md')
    if rel == 'README.md':
        return Path('index.md')
    if rel == 'bootstrap/README.md':
        return Path('guides/backend.md')
    if rel.startswith('docs/') and rel.endswith('.md'):
        return Path('guides') / source.name
    return None

def convert_links(text, source, destination):
    def repl(m):
        href = m[2]
        if urlparse(href).scheme or href.startswith(('#','//','mailto:')):
            return m[0]
        raw, sep, anchor = href.partition('#')
        target = (source.parent / unquote(raw)).resolve()
        if not target.is_relative_to(ROOT):
            return m[0]
        if target.is_dir():
            target = target / 'README.md'
        if target.suffix.lower() in ('.svg','.png','.jpg') and 'assets' in target.parts:
            mapped_path = Path('assets') / target.relative_to(ROOT / 'assets')
        else:
            mapped_path = mapped(target)
        if mapped_path:
            new = os.path.relpath(mapped_path, destination.parent).replace('\\','/')
            if sep: new += '#' + anchor
        else:
            new = BASE + target.relative_to(ROOT).as_posix()
            if sep: new += '#' + anchor
        return m[1] + new + ')'
    return re.sub(r'(!?\[[^\]]*\]\()([^\s)]+)\)', repl, text)

def main():
    catalog = json.loads((ROOT/'curriculum/labs.json').read_text(encoding='utf-8'))
    if OUT.exists():
        # Only remove this tool's generated, ignored tree inside the repository.
        assert OUT.resolve().parent == ROOT.resolve() and OUT.name == '.site-docs'
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(ROOT/'assets', OUT/'assets')
    shutil.copytree(ROOT/'web', OUT/'web')
    nav = [{'Start here':'index.md'}]
    phase_nav = []
    for phase in catalog['phases']:
        selected = [l for l in catalog['labs'] if l['phase']==phase['id']]
        phase_doc=f'phases/phase-{phase["id"]}.md'
        intro = f'# Phase {phase["id"]} · {phase["title"]}\n\n{phase["description"]}\n\n'
        intro += f'![Phase {phase["id"]}: {phase["title"]}](../assets/illustrations/phase-{phase["id"]}.svg)\n\n'
        intro += '| Lab | Outcome | Cost | Mode |\n|---|---|---|---|\n'
        for l in selected:
            intro += f'| [{l["id"]} · {l["title"]}](../labs/{l["id"]}.md) | {l["outcome"]} | {l["cost"]} | {l["run_mode"]} |\n'
        write(phase_doc,intro)
        phase_nav.append({f'{phase["id"]} · {phase["title"]}': [{'Phase overview':phase_doc}]+[{f'{l["id"]} · {l["title"]}': f'labs/{l["id"]}.md'} for l in selected]})
    nav.append({'Learning phases':phase_nav})
    sources = [ROOT/'README.md', ROOT/'bootstrap/README.md'] + sorted((ROOT/'docs').glob('*.md'))
    sources += [ROOT/l['path']/'README.md' for l in catalog['labs']]
    for source in sources:
        if not source.exists():
            raise SystemExit(f'Missing authoritative source: {source}')
        dest = mapped(source)
        body = convert_links(source.read_text(encoding='utf-8'),source,dest)
        if source.parent.name.startswith('TFA-'):
            lab_id = source.parent.name
            index = next(i for i,l in enumerate(catalog['labs']) if l['id']==lab_id)
            lab = catalog['labs'][index]
            bar = f'<div class="lab-meta"><span>{lab["cost"]} cost</span><span>{lab["run_mode"]}</span><span>{lab["duration_minutes"]} min learning target</span></div>\n\n'
            body = body.replace('\n', '\n\n'+bar, 1)
            if f'assets/diagrams/{lab_id}.svg' not in body:
                body += f'\n\n![{lab_id} teaching flow](../assets/diagrams/{lab_id}.svg)\n'
            body += f'\n\n## Check your understanding\n\n<div class="course-quiz" data-lab="{lab_id}"></div>\n\n'
            body += f'<div class="course-completion" data-lab="{lab_id}"></div>\n\n'
            previous = catalog['labs'][index-1] if index else None
            following = catalog['labs'][index+1] if index+1<len(catalog['labs']) else None
            body += ('[← '+previous['id']+']('+previous['id']+'.md)' if previous else '[Course home](../index.md)')
            if following: body += ' · [Next: '+following['id']+' →]('+following['id']+'.md)'
        write(dest,body)
    quizzes={}
    for l in catalog['labs']:
        quizzes[l['id']] = json.loads((ROOT/l['quiz']).read_text(encoding='utf-8'))
    write('web/quizzes.json',json.dumps(quizzes,ensure_ascii=False))
    write('web/catalog.json',json.dumps(catalog,ensure_ascii=False))
    write('progress.md','# Your learning progress\n\nProgress is saved in this browser only. Exercise and cleanup completion are self-reported; no Azure resources are inspected.\n\n<div id="course-progress"></div>\n')
    write('practice.md','# Practice questions\n\nChoose a lab to revisit its five questions. Answers include explanations; your score stays in this browser.\n\n<label for="practice-lab">Lab</label> <select id="practice-lab"></select>\n\n<div id="practice-quiz" class="course-quiz"></div>\n')
    nav.extend([{'Architecture':'guides/architecture.md'}, {'Practice':'practice.md'}, {'Your progress':'progress.md'}, {'Run safely':[{'Cost and cleanup':'guides/cost-and-cleanup.md'},{'Backend bootstrap':'guides/backend.md'},{'Delivery and OIDC':'guides/delivery.md'},{'Troubleshooting':'guides/troubleshooting.md'},{'Glossary':'guides/glossary.md'},{'Live smoke tests':'guides/live-smoke-tests.md'},{'Validation status':'guides/validation.md'}]}])
    config={'site_name':'Terraforming Azure','site_description':'A Windows-first journey from Terraform basics to a complete Azure hub-and-spoke network.',
        'site_url':'https://jamonygr.github.io/Terraforming-Azure/','repo_url':'https://github.com/Jamonygr/Terraforming-Azure','repo_name':'Jamonygr/Terraforming-Azure',
        'docs_dir':'.site-docs','site_dir':'site','use_directory_urls':True,
        'theme':{'name':'material','font':False,'features':['navigation.tabs','navigation.sections','navigation.top','search.highlight','content.code.copy'],
        'palette':[{'scheme':'slate','primary':'indigo','accent':'cyan','toggle':{'icon':'material/brightness-4','name':'Use light theme'}},{'scheme':'default','primary':'indigo','accent':'deep purple','toggle':{'icon':'material/brightness-7','name':'Use dark theme'}}]},
        'nav':nav,'plugins':[{'search':{'lang':'en'}}],
        'markdown_extensions':['admonition','attr_list','md_in_html','tables',{'toc':{'permalink':True}},'pymdownx.details','pymdownx.highlight','pymdownx.superfences'],
        'extra_css':['web/course.css'],'extra_javascript':['web/course.js'],
        'validation':{'links':{'unrecognized_links':'warn','not_found':'warn','anchors':'warn'}}}
    (ROOT/'mkdocs.yml').write_text(yaml.safe_dump(config,sort_keys=False,allow_unicode=True),encoding='utf-8')
    print(f'Built source: {len(catalog["labs"])} lessons, {sum(map(len,quizzes.values()))} questions, {len(catalog["phases"])} phases.')

if __name__=='__main__':
    main()
