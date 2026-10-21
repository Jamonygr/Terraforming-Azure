"""Reject unmocked external providers before any Terraform test is started."""
from pathlib import Path
import hcl2

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = hcl2.utils.SerializationOptions(strip_string_quotes=True, with_comments=False, explicit_blocks=False)


def read_hcl(path):
    return hcl2.loads(path.read_text(encoding='utf-8'), serialization_options=OPTIONS)


def blocks(document, kind):
    for block in document.get(kind, []):
        yield from block.items()


def provider_address(name, config):
    return name + ('.' + config['alias'] if 'alias' in config else '')


def references(mapping):
    return {key.removeprefix('${').removesuffix('}'): value.removeprefix('${').removesuffix('}') for key, value in mapping.items()}


def requirements(folder, visited=None):
    """Find provider configurations and inherited provider names in local modules."""
    visited = set() if visited is None else visited
    folder = folder.resolve()
    if folder in visited:
        return set()
    visited.add(folder)
    required = set()
    for file in folder.glob('*.tf'):
        doc = read_hcl(file)
        for name, config in blocks(doc, 'provider'):
            if name != 'terraform':
                required.add(provider_address(name, config))
        for kind in ('resource', 'data'):
            for resource_type, resources in blocks(doc, kind):
                for config in resources.values():
                    if config.get('provisioner'):
                        raise ValueError(f'{file}: provisioners require separate fixture tests, not terraform test')
                    if resource_type == 'terraform_remote_state' and config.get('backend') != 'local':
                        raise ValueError(f'{file}: remote state reads are not permitted in offline tests')
                    if resource_type.startswith('terraform_'):
                        continue
                    required.add(config.get('provider', resource_type.split('_')[0]).removeprefix('${').removesuffix('}'))
        for _, module in blocks(doc, 'module'):
            source = module.get('source', '')
            if not source.startswith('.'):
                raise ValueError(f'{file}: offline test policy requires reviewed local modules')
            mapping = references(module.get('providers', {}))
            for child in requirements(folder / source, visited.copy()):
                required.add(mapping.get(child, child).removeprefix('${').removesuffix('}'))
    return required


def check_folder(folder):
    issues = []
    for file in sorted((folder / 'tests').glob('*.tftest.hcl')):
        try:
            doc = read_hcl(file)
            mocks = {provider_address(name, config) for name, config in blocks(doc, 'mock_provider')}
            if doc.get('provider'):
                issues.append(f'{file}: real provider blocks are not permitted in course tests')
            runs = list(blocks(doc, 'run'))
            for name, run in runs:
                target = folder
                if run.get('module'):
                    source = run['module'][0].get('source', '')
                    if not source.startswith('.'):
                        raise ValueError(f'{file}: run {name} must use a reviewed local module')
                    target = folder / source
                mapping = references(run.get('providers', {}))
                for provider in requirements(target):
                    mapped = mapping.get(provider, provider).removeprefix('${').removesuffix('}')
                    if mapped not in mocks:
                        issues.append(f'{file}: run {name} uses {provider} without mock_provider {mapped}')
        except (ValueError, TypeError, KeyError) as error:
            issues.append(str(error))
    return issues


def main():
    folders = sorted({p.parent.parent for p in ROOT.rglob('*.tftest.hcl') if not set(p.parts) & {'.terraform', '.venv', 'work', 'node_modules'}})
    issues = [issue for folder in folders for issue in check_folder(folder)]
    for issue in issues:
        print('FAIL ' + issue)
    if issues:
        raise SystemExit(1)
    print(f'PASS: all external provider references in {len(folders)} test roots are mocked.')


if __name__ == '__main__':
    main()
