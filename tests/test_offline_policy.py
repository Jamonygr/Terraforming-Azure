from pathlib import Path
import tempfile
import unittest
from tools.check_offline_tests import check_folder


class OfflineProviderPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tests').mkdir()
        (self.root / 'main.tf').write_text('resource "azurerm_resource_group" "example" {}')

    def suite(self, source):
        (self.root / 'tests' / 'example.tftest.hcl').write_text(source)
        return check_folder(self.root)

    def test_real_provider_cannot_run(self):
        self.assertTrue(self.suite('provider "azurerm" { features {} }\nrun "case" {command=plan}'))

    def test_comment_is_not_a_mock(self):
        self.assertTrue(self.suite('# mock_provider "azurerm" {}\nrun "case" { command=plan }'))

    def test_mocked_provider_can_run(self):
        self.assertEqual(self.suite('mock_provider "azurerm" {}\nrun "case" {command=apply}'), [])

    def test_alias_requires_matching_mock_or_explicit_mapping(self):
        (self.root / 'main.tf').write_text('provider "azurerm" {alias="other"}\nresource "azurerm_resource_group" "example" {provider=azurerm.other}')
        self.assertTrue(self.suite('mock_provider "azurerm" {}\nrun "case" {command=plan}'))
        self.assertEqual(self.suite('mock_provider "azurerm" {alias="safe"}\nrun "case" {command=plan providers={azurerm.other=azurerm.safe}}'), [])

    def test_child_module_cannot_hide_a_real_provider(self):
        child = self.root / 'child'
        child.mkdir()
        (child / 'main.tf').write_text('resource "azuread_application" "example" {}')
        (self.root / 'main.tf').write_text('module "child" {source="./child"}')
        self.assertTrue(self.suite('mock_provider "azurerm" {}\nrun "case" {command=plan}'))


if __name__ == '__main__':
    unittest.main()
