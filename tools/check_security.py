"""Focused source policies. This is not an Azure or general-purpose secret scan."""
from pathlib import Path
import argparse
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
STAGE = re.compile(r'labs/TFA-040/stages/(foundation|secure|applications|hybrid)\.tfvars')
CREDENTIALS = (
    r'gh[pousr]_[A-Za-z0-9]{30,}',
    r'github_pat_[A-Za-z0-9_]{50,}',
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    r'AccountKey=[A-Za-z0-9+/]{40,}={0,2}',
)


def protected_file(name):
    """Examples are deliberately named; ignored files forced into Git are still checked."""
    leaf = Path(name).name.lower()
    if leaf.endswith(('.tfvars.example', '.tfvars.json.example', '.tfvars.example.json')):
        return False
    return bool(
        re.search(r'\.tfstate(?:\.|$)|\.tfplan(?:\.|$)', leaf)
        or leaf == 'tfplan' or leaf.startswith('tfplan.')
        or leaf.endswith(('.tfvars', '.tfvars.json', '.pfx', '.p12', '.pem', '.key'))
        or leaf in {'state.json', 'plan.json', 'terraform-plan.json', 'bootstrap-state.backup.json'}
        or (leaf == '.env' or leaf.startswith('.env.')) and leaf != '.env.example'
    )


def scan(root):
    names = subprocess.run(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=root, capture_output=True, check=True,
    ).stdout.decode('utf-8').split('\0')
    issues = []
    for name in sorted(set(filter(None, names))):
        path = root / name
        if not path.is_file():
            continue
        stage = STAGE.fullmatch(name)
        if stage:
            expected = rf'\s*stage\s*=\s*"{stage[1]}"\s*'
            if not re.fullmatch(expected, path.read_text(encoding='utf-8')):
                issues.append(f'{name}: approved stage files may contain only their stage selector')
        elif protected_file(name):
            issues.append(f'{name}: sensitive generated file must not be tracked')
        if path.suffix.lower() in ('.tf', '.ps1', '.yml', '.yaml', '.py', '.json', '.md', '.example', '.hcl', '.txt'):
            content = path.read_text(encoding='utf-8')
            if any(re.search(pattern, content) for pattern in CREDENTIALS):
                issues.append(f'{name}: possible committed credential (value redacted)')
            if path.suffix == '.tf':
                for nic in re.findall(r'resource\s+"azurerm_network_interface"\s+"[^"]+"\s*\{(.*?)(?=\nresource |\noutput |\Z)', content, flags=re.S):
                    if re.search(r'public_ip_address_id\s*=', nic):
                        issues.append(f'{name}: VM public IP contradicts course private-VM policy')
                if re.search(r'(admin_password|certificate_password|vpn_shared_key)\s*=\s*"[^"$][^"]{7,}"', content):
                    issues.append(f'{name}: possible hardcoded credential (value redacted)')
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT, help='Git root; supports isolated synthetic regression fixtures')
    args = parser.parse_args()
    issues = scan(args.root.resolve())
    for issue in issues:
        print('FAIL ' + issue)
    if issues:
        raise SystemExit(1)
    print('PASS: focused credential, generated-file and private-VM source policies. Azure runtime unverified.')


if __name__ == '__main__':
    main()