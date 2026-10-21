"""Prove architecture assertions reject dangerous changes in isolated mocked copies.

No real provider applies, Azure credentials or subscription calls are used.
Terraform may download the pinned provider schema during init if it is not cached.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.gettempdir()).resolve() / 'Terraforming-Azure-mutation-checks'
CASES = [
    ('public-nic', 'compute.tf', 'private_ip_address            = each.value.address',
     'private_ip_address            = each.value.address\n    public_ip_address_id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/mock-rg/providers/Microsoft.Network/publicIPAddresses/unexpected"',
     'Each workload NIC must remain private-only.'),
    ('ingress-forced-tunnel', 'network.tf', 'subnet_id      = azurerm_subnet.subnet[each.key].id',
     'subnet_id      = azurerm_subnet.subnet[each.key == "app" ? "ingress" : each.key].id', 'CONTRACT:'),
    ('disabled-pe-policies', 'network.tf', 'each.key == "data" ? "Enabled" : "Disabled"', '"Disabled"',
     'PE subnet route policies'),
    ('widened-firewall-rule', 'security.tf',
     'source_addresses      = [local.subnets.operations.prefix, local.subnets.corp.prefix]',
     'source_addresses      = ["*"]', 'FIREWALL:'),
    ('missing-return-route', 'network.tf', 'if pair[0] != pair[1]',
     'if pair[0] != pair[1] && "${pair[0]}-${pair[1]}" != "operations-app"',
     'explicit private-prefix'),
]

def run(command, folder, env):
    completed = subprocess.run(command, cwd=folder, env=env, text=True, encoding='utf-8',
                               errors='replace', capture_output=True, timeout=180)
    return completed.returncode, completed.stdout + completed.stderr


def main():
    import sys
    if sys.version_info < (3, 12):
        raise RuntimeError('Use Python 3.12+ from the course contributor environment.')
    WORK.mkdir(parents=True, exist_ok=True)
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('ARM_', 'AZURE_', 'TF_VAR_', 'TF_CLI_ARGS'))}
    env['TF_IN_AUTOMATION'] = 'true'
    status, output = run([sys.executable, str(ROOT / 'tools' / 'check_offline_tests.py')], ROOT, env)
    if status:
        raise RuntimeError('Offline provider guard failed before any test could run:\n' + output[:12000])
    with tempfile.TemporaryDirectory(prefix='case-', dir=WORK, ignore_cleanup_errors=True) as temporary:
        scratch = Path(temporary).resolve()
        # Resolve and check the owned temporary boundary before recursive cleanup.
        scratch.relative_to(WORK.resolve())
        module = scratch / 'modules' / 'capstone'
        shutil.copytree(ROOT / 'modules' / 'capstone', module,
                        ignore=shutil.ignore_patterns('.terraform', '*.tfstate*', 'crash.log'))
        fixture = scratch / 'labs' / 'TFA-040' / 'tests' / 'fixtures'
        fixture.mkdir(parents=True)
        shutil.copy2(ROOT / 'labs' / 'TFA-040' / 'tests' / 'fixtures' / 'certificate.fixture', fixture)
        init = ['terraform', 'init', '-backend=false', '-input=false', '-lockfile=readonly', '-no-color']
        mirror = ROOT / 'modules' / 'capstone' / '.terraform' / 'providers'
        if mirror.exists():
            init.append('-plugin-dir=' + str(mirror))
        status, output = run(init, module, env)
        if status:
            raise RuntimeError('Mock mutation initialization failed:\n' + output)
        status, output = run(['terraform', 'test', '-no-color'], module, env)
        if status:
            raise RuntimeError('Unmodified baseline failed:\n' + output)
        print('PASS unmodified mock baseline', flush=True)
        for name, filename, before, after, expected in CASES:
            path = module / filename
            original = path.read_text(encoding='utf-8')
            if original.count(before) != 1:
                raise RuntimeError(name + ': mutation anchor is missing or ambiguous')
            try:
                with path.open('w', encoding='utf-8', newline='\n') as handle:
                    handle.write(original.replace(before, after, 1))
                status, output = run(['terraform', 'test', '-no-color'], module, env)
                if status == 0 or 'Error: Test assertion failed' not in output or expected not in output:
                    raise RuntimeError(name + ' was not rejected by its intended assertion:\n' + output[:12000])
                print('PASS rejected ' + name, flush=True)
            finally:
                with path.open('w', encoding='utf-8', newline='\n') as handle:
                    handle.write(original)
        scratch.relative_to(WORK.resolve())
        time.sleep(0.2)
    print('Five targeted Terraform mutations rejected. Azure runtime remains unverified.')


if __name__ == '__main__':
    main()
