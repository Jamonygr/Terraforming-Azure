"""Synthetic files only; no real secrets, Azure access, or changes to the checkout."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from tools.check_security import ROOT, scan


class SourceSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '--quiet', str(self.root)], check=True)
        (self.root / '.gitignore').write_text((ROOT / '.gitignore').read_text(), encoding='utf-8')

    def put(self, name, value='synthetic test content', force=False):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf-8')
        if force:
            subprocess.run(['git', 'add', '--force', '--', name], cwd=self.root, check=True)

    def test_protected_formats_are_ignored_and_force_added_files_are_rejected(self):
        names = ['terraform.tfvars', 'terraform.tfvars.json', 'lab.auto.tfvars.json',
                 'terraform.tfstate', 'terraform.tfstate.backup', 'state.tfstate.json',
                 'tfplan', 'tfplan.json', 'saved.tfplan', 'saved.tfplan.json',
                 'plan.json', 'state.json', 'lab.pfx', 'signing.pem', 'secret.key', '.env.private']
        for name in names:
            with self.subTest(name=name):
                self.put(name)
                result = subprocess.run(['git', 'check-ignore', '--quiet', '--', name], cwd=self.root)
                self.assertEqual(result.returncode, 0)
                self.put(name, force=True)
                self.assertTrue(any(issue.startswith(name + ':') for issue in scan(self.root)))

    def test_ordinary_json_variables_are_rejected_without_ignore_rules(self):
        (self.root / '.gitignore').unlink()
        self.put('terraform.tfvars.json', '{"admin_password":"synthetic-fixture-only"}')
        self.assertTrue(any('terraform.tfvars.json' in item for item in scan(self.root)))

    def test_example_and_exact_stage_exceptions(self):
        for name in ['terraform.tfvars.example', 'terraform.tfvars.json.example', 'terraform.tfvars.example.json']:
            self.put(name, '{}')
            self.assertNotEqual(subprocess.run(['git', 'check-ignore', '--quiet', '--', name], cwd=self.root).returncode, 0)
        self.put('labs/TFA-040/stages/hybrid.tfvars', 'stage = "hybrid"\n')
        self.assertEqual(scan(self.root), [])
        self.put('labs/TFA-040/stages/hybrid.tfvars', 'stage = "hybrid"\nadmin_password = "fixture"')
        self.assertTrue(any('only their stage selector' in issue for issue in scan(self.root)))

    def test_token_and_private_key_markers_report_no_value(self):
        token = 'gh' + 'p_' + 'x' * 36
        key = '-----BEGIN ' + 'PRIVATE KEY-----'
        self.put('fixture.txt', token + '\n' + key)
        issues = scan(self.root)
        self.assertEqual(len(issues), 1)
        self.assertNotIn(token, issues[0])

    def test_private_vm_policy(self):
        self.put('main.tf', 'resource "azurerm_network_interface" "vm" {\n ip_configuration {\n public_ip_address_id = var.public_ip\n }\n}')
        self.assertTrue(any('VM public IP' in issue for issue in scan(self.root)))


if __name__ == '__main__':
    unittest.main()
