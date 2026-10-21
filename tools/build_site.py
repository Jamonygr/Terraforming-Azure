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
import hashlib
import xml.etree.ElementTree as ET
from urllib.parse import urlparse, unquote
import yaml

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.site-docs'
BASE = 'https://github.com/Jamonygr/Terraforming-Azure/blob/main/'

def lesson_metadata(lab, catalog):
    """Shared source block. Links are converted for the website like other links."""
    titles = {entry['id']: entry['title'] for entry in catalog['labs']}
    prerequisites = ', '.join(f'[{item} — {titles[item]}](../{item}/README.md)' for item in lab['prerequisites']) or 'None — start here.'
    phase = next((entry for entry in catalog.get('phases', []) if entry['id'] == lab.get('phase')), None)
    phase_line = f'**Phase {phase["id"]}:** {phase["title"]}\n\n' if phase else ''
    return ('<!-- lab-metadata:start -->\n'
            + phase_line +
            f'**Learning target:** {lab["duration_minutes"]} minutes · **Cost tier:** {lab["cost"]} · **Run mode:** `{lab["run_mode"]}`\n\n'
            f'**Prerequisites:** {prerequisites}\n'
            '<!-- lab-metadata:end -->')

def lesson_source(body, lab, catalog):
    """Update only marked catalog-owned blocks, preserving authored prose."""
    metadata = lesson_metadata(lab, catalog)
    if '<!-- lab-metadata:start -->' in body:
        body = re.sub(r'<!-- lab-metadata:start -->.*?<!-- lab-metadata:end -->', lambda _: metadata, body, flags=re.S)
    else:
        body = body.replace('\n', '\n\n' + metadata + '\n', 1)
    diagram = ('<!-- lab-diagram:start -->\n'
               f'![{lab["id"]} teaching diagram](../../{lab["diagram"]})\n'
               '<!-- lab-diagram:end -->')
    if '<!-- lab-diagram:start -->' in body:
        body = re.sub(r'<!-- lab-diagram:start -->.*?<!-- lab-diagram:end -->', lambda _: diagram, body, flags=re.S)
    else:
        pattern = r'!\[[^\]]*\]\([^\s)]*assets/diagrams/' + re.escape(lab['id']) + r'\.svg\)'
        body, count = re.subn(pattern, lambda _: diagram, body, count=1)
        if not count:
            body = body.replace('<!-- lab-metadata:end -->', '<!-- lab-metadata:end -->\n\n' + diagram, 1)
    return body

def web_questions(questions):
    """Answer identity survives reordering; content revisions invalidate old attempts."""
    result = []
    for question in questions:
        options = [{'id': 'o-' + hashlib.sha256(text.encode()).hexdigest()[:16], 'text': text} for text in question['options']]
        record = {**question, 'options': options, 'answer': options[question['answer']]['id']}
        canonical = {**record, 'options': sorted(options, key=lambda item: item['id'])}
        record['revision'] = hashlib.sha256(json.dumps(canonical, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]
        result.append(record)
    return result

def decorate_images(body, destination):
    def replace(match):
        alt, url = match[1], match[2]
        if urlparse(url).scheme:
            return match[0]
        if 'assets/diagrams/' in url and url.endswith('.svg'):
            source = (OUT / destination.parent / url).resolve()
            svg = ET.parse(source).getroot()
            dimensions = f'{{ width="{svg.attrib.get("width", "1200")}" height="{svg.attrib.get("height", "800")}" loading="lazy" }}'
            return f'![{alt}]({url}){dimensions}\n\n[Open full-size diagram: {alt}]({url}){{ target="_blank" rel="noopener" }}'
        if url.endswith('terraforming-azure-cover.png'):
            from PIL import Image
            image_path = (OUT / destination.parent / url).with_suffix('.webp')
            with Image.open(image_path) as image:
                width, height = image.size
            return f'![{alt}]({url[:-4]}.webp){{ width="{width}" height="{height}" fetchpriority="high" }}'
        return match[0]
    return re.sub(r'!\[([^\]]*)\]\(([^\s)]+)\)', replace, body)

def write(path, content):
    target = OUT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8', newline='\n')

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
    shutil.copytree(ROOT/'web', OUT/'web', ignore=shutil.ignore_patterns('overrides'))
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
        body = source.read_text(encoding='utf-8')
        if source.parent.name.startswith('TFA-'):
            lab_id = source.parent.name
            index = next(i for i,l in enumerate(catalog['labs']) if l['id']==lab_id)
            lab = catalog['labs'][index]
            body = lesson_source(body, lab, catalog)
            body = convert_links(body, source, dest)
            body += f'\n\n## Check your understanding\n\n<div class="course-quiz" data-lab="{lab_id}"></div>\n\n'
            body += f'<noscript>Enable JavaScript for interactive questions, or <a href="{BASE}labs/{lab_id}/quiz.json">read this lesson’s questions in the repository</a>.</noscript>\n\n'
            body += f'<div class="course-completion" data-lab="{lab_id}"></div>\n\n'
            previous = catalog['labs'][index-1] if index else None
            following = catalog['labs'][index+1] if index+1<len(catalog['labs']) else None
            body += ('[← '+previous['id']+']('+previous['id']+'.md)' if previous else '[Course home](../index.md)')
            if following: body += ' · [Next: '+following['id']+' →]('+following['id']+'.md)'
        else:
            body = convert_links(body, source, dest)
        write(dest,decorate_images(body, dest))
    quizzes={}
    for l in catalog['labs']:
        quizzes[l['id']] = web_questions(json.loads((ROOT/l['quiz']).read_text(encoding='utf-8')))
    write('web/quizzes.json',json.dumps(quizzes,ensure_ascii=False))
    write('web/catalog.json',json.dumps(catalog,ensure_ascii=False))
    write('progress.md','# Your learning progress\n\nProgress is saved in this browser only. Exercise and cleanup completion are self-reported; no Azure resources are inspected. Quiz scores count your latest checked answer to each current question. Changing a question invalidates its previous answer. Export a backup before clearing browser data.\n\n<div id="course-progress"></div>\n\n<noscript>Enable JavaScript to view and export browser-local progress.</noscript>\n')
    write('practice.md','# Practice questions\n\nChoose a lab to revisit its five questions. Your selected answers and feedback are restored. Scores count your latest checked attempt. Option order is mixed consistently; correctness is attached to the answer, not its position.\n\n<label for="practice-lab">Lab</label> <select id="practice-lab"></select>\n\n<div id="practice-quiz" class="course-quiz"></div>\n\n<noscript>Enable JavaScript for practice questions, or open the lesson quiz.json files in the repository.</noscript>\n')
    nav.extend([{'Architecture':'guides/architecture.md'}, {'Practice':'practice.md'}, {'Your progress':'progress.md'}, {'Run safely':[{'Cost and cleanup':'guides/cost-and-cleanup.md'},{'Backend bootstrap':'guides/backend.md'},{'Delivery and OIDC':'guides/delivery.md'},{'Troubleshooting':'guides/troubleshooting.md'},{'Glossary':'guides/glossary.md'},{'Live smoke tests':'guides/live-smoke-tests.md'},{'Validation status':'guides/validation.md'}]}])
    if (ROOT/'docs/cost-estimates.md').exists():
        nav[-1]['Run safely'].insert(1, {'Cost estimates': 'guides/cost-estimates.md'})
    if (ROOT/'docs/traffic-matrix.md').exists():
        nav[-4] = {'Architecture': [{'Overview': 'guides/architecture.md'}, {'Traffic matrix': 'guides/traffic-matrix.md'}]}
    if (ROOT/'docs/overhaul-status.md').exists():
        nav[-1]['Run safely'].append({'Overhaul status': 'guides/overhaul-status.md'})
    if (ROOT/'docs/curriculum-evidence.md').exists():
        nav[-1]['Run safely'].append({'Curriculum evidence': 'guides/curriculum-evidence.md'})
    config={'site_name':'Terraforming Azure','site_description':'A Windows-first journey from Terraform basics to a complete Azure hub-and-spoke network.',
        'site_url':'https://jamonygr.github.io/Terraforming-Azure/','repo_url':'https://github.com/Jamonygr/Terraforming-Azure','repo_name':'Jamonygr/Terraforming-Azure',
        'docs_dir':'.site-docs','site_dir':'site','use_directory_urls':True,
        'theme':{'name':'material','custom_dir':'web/overrides','font':False,'features':['navigation.tabs','navigation.sections','navigation.top','search.highlight','content.code.copy'],
        'palette':[{'scheme':'slate','primary':'indigo','accent':'cyan','toggle':{'icon':'material/brightness-4','name':'Use light theme'}},{'scheme':'default','primary':'indigo','accent':'deep purple','toggle':{'icon':'material/brightness-7','name':'Use dark theme'}}]},
        'nav':nav,'plugins':[{'search':{'lang':'en'}}],
        'markdown_extensions':['admonition','attr_list','md_in_html','tables',{'toc':{'permalink':True}},'pymdownx.details','pymdownx.highlight','pymdownx.superfences'],
        'extra_css':['web/course.css'],'extra_javascript':['web/progress.js','web/course.js'],
        'validation':{'links':{'unrecognized_links':'warn','not_found':'warn','anchors':'warn'}}}
    (ROOT/'mkdocs.yml').write_text('# Generated by tools/build_site.py. Edit the generator or curriculum catalog.\n' + yaml.safe_dump(config,sort_keys=False,allow_unicode=True),encoding='utf-8',newline='\n')
    print(f'Built source: {len(catalog["labs"])} lessons, {sum(map(len,quizzes.values()))} questions, {len(catalog["phases"])} phases.')

if __name__=='__main__':
    main()
