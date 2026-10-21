"""Inspect generated pages and same-site links without executing browser code."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlparse, unquote
import json

ROOT=Path(__file__).resolve().parents[1]; SITE=ROOT/'site'
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        for k,v in attrs:
            if (tag,k) in [('a','href'),('img','src'),('script','src'),('link','href')] and v:self.links.append(v)
errors=[]
for source in SITE.rglob('*.html'):
    p=Links();p.feed(source.read_text(encoding='utf-8'))
    for href in p.links:
        parsed=urlparse(href)
        if parsed.scheme or href.startswith(('#','//')):continue
        target=(source.parent/unquote(parsed.path)).resolve()
        if not target.is_relative_to(SITE.resolve()):continue
        if target.is_dir():target=target/'index.html'
        if not target.exists():errors.append(f'{source.relative_to(SITE)}: missing {href}')
for i in range(1,41):
    page=SITE/f'labs/TFA-{i:03}/index.html'
    if not page.exists():errors.append(f'Missing lab page {i}')
    elif 'course-quiz' not in page.read_text(encoding='utf-8'):errors.append(f'Missing quiz hook {i}')
quizzes=json.loads((SITE/'web/quizzes.json').read_text(encoding='utf-8'))
if sum(map(len,quizzes.values()))!=200:errors.append('Built question count is not 200')
if errors:
    print('\n'.join(errors));raise SystemExit(1)
print('PASS: 40 built lesson pages, 200 questions, same-site links and assets.')
