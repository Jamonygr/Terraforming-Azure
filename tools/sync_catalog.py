"""Synchronize the README table from the only authoritative curriculum catalog."""
from pathlib import Path
import argparse
import json
import re

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
labs=json.loads((ROOT/'curriculum/labs.json').read_text(encoding='utf-8'))['labs']
rows='\n'.join(f'| [{l["id"]}]({l["path"]}/README.md) | {l["title"]} | {l["phase"]} | {l["cost"]} | {l["run_mode"]} |' for l in labs)
table='<!-- curriculum:start -->\n| Lab | Lesson | Phase | Cost tier | Run mode |\n|---|---|---|---|---|\n'+rows+'\n<!-- curriculum:end -->'
readme=ROOT/'README.md';before=readme.read_text(encoding='utf-8')
after=re.sub(r'<!-- curriculum:start -->.*?<!-- curriculum:end -->',lambda _:table,before,flags=re.S)
if args.check:
    if before!=after:raise SystemExit('README curriculum is stale. Run python tools/sync_catalog.py.')
    print('PASS: README curriculum matches authoritative catalog.')
else:readme.write_text(after,encoding='utf-8')
