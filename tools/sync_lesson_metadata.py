"""Generate shared lesson metadata/diagrams from the catalog, or verify --check."""
import argparse
import json
from build_site import ROOT, lesson_source

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    catalog = json.loads((ROOT / 'curriculum/labs.json').read_text(encoding='utf-8'))
    changed = []
    for lab in catalog['labs']:
        path = ROOT / lab['path'] / 'README.md'
        before = path.read_text(encoding='utf-8')
        after = lesson_source(before, lab, catalog)
        if after != before:
            changed.append(lab['id'])
            if not args.check:
                path.write_text(after, encoding='utf-8', newline='\n')
    if args.check and changed:
        raise SystemExit('Run python tools/sync_lesson_metadata.py: ' + ', '.join(changed))
    print(f'PASS: shared metadata for {len(catalog["labs"])} lessons' if args.check else f'Updated {len(changed)} lesson metadata blocks.')

if __name__ == '__main__':
    main()
