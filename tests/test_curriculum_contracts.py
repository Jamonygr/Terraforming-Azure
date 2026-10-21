"""Regression contracts for the authored curriculum; no cloud or network calls."""
from pathlib import Path
import hashlib
import json
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class CurriculumContracts(unittest.TestCase):
    def test_all_outcomes_have_evidence_and_real_sources(self):
        catalog = json.loads((ROOT / 'curriculum/labs.json').read_text(encoding='utf-8'))['labs']
        evidence = json.loads((ROOT / 'curriculum/evidence.json').read_text(encoding='utf-8'))['labs']
        self.assertEqual([x['id'] for x in evidence], [x['id'] for x in catalog])
        for actual, expected in zip(evidence, catalog):
            with self.subTest(lab=actual['id']):
                self.assertEqual(actual['outcome'], expected['outcome'])
                for field in ['mechanism', 'probe', 'expected', 'failure_and_repair', 'cleanup', 'cleanup_dependency']:
                    self.assertGreater(len(actual[field].split()), 5, field)
                for path in actual['sources'] + actual['test_sources']:
                    self.assertTrue((ROOT / path).is_file(), path)
                self.assertEqual(actual['runtime_validation'], 'not_run_azure')
        self.assertIn('Migrate', evidence[15]['cleanup_dependency'])
        self.assertIn('bootstrap', evidence[39]['cleanup_dependency'])

    def test_all_questions_match_editorial_review_revision(self):
        review = json.loads((ROOT / 'assessments/editorial-review.json').read_text(encoding='utf-8'))
        reviewed = {x['id']: x for x in review['questions']}
        self.assertEqual(len(reviewed), 200)
        cyclic = 0
        positions = set()
        for number in range(1, 41):
            questions = json.loads((ROOT / f'labs/TFA-{number:03}/quiz.json').read_text(encoding='utf-8'))
            answers = [q['answer'] for q in questions]
            cyclic += all(answers[j] == (answers[0] + j) % 4 for j in range(5))
            for q in questions:
                self.assertEqual(len(set(q['options'])), 4)
                self.assertIn(q['answer'], range(4))
                positions.add(q['answer'])
                canonical = json.dumps(q, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
                self.assertEqual(reviewed[q['id']]['content_sha256'], hashlib.sha256(canonical.encode('utf-8')).hexdigest())
                self.assertEqual(reviewed[q['id']]['revision'], 2)
        self.assertEqual(positions, {0, 1, 2, 3})
        self.assertLess(cyclic, 4, 'The old cyclic correct-answer pattern must not dominate the bank.')

    def test_cleanup_uses_actual_group_and_stops_on_failure(self):
        for number in range(22, 40):
            text = (ROOT / f'labs/TFA-{number:03}/README.md').read_text(encoding='utf-8')
            if 'az group exists' in text:
                with self.subTest(lab=number):
                    self.assertNotRegex(text, r'az group exists[^\n]*--name rg-tfa\d+')
                    self.assertIn('$cleanupGroup = terraform output -raw resource_group_name', text)
                    self.assertIn("throw 'Destroy failed:", text)
                    cleanup = text[text.index('## Cleanup'):]
                    self.assertRegex(cleanup, r"terraform plan -destroy[^\n]*-out=cleanup\.tfplan\nif \(\$LASTEXITCODE -ne 0\).*throw")
                    self.assertRegex(cleanup, r"terraform show cleanup\.tfplan\nif \(\$LASTEXITCODE -ne 0\).*throw")

    def test_backend_initial_creation_does_not_wait_for_its_future_role(self):
        provider = (ROOT / 'labs/TFA-016/versions.tf').read_text(encoding='utf-8')
        instructions = (ROOT / 'labs/TFA-016/README.md').read_text(encoding='utf-8')
        self.assertRegex(provider, r'data_plane_available\s*=\s*false')
        self.assertIn('AddMinutes(10)', instructions)
        self.assertIn('terraform init -migrate-state', instructions)
        self.assertRegex(instructions, r'if \(\$LASTEXITCODE -ne 0\).*throw')

    def test_technical_diagrams_have_accessible_explanation(self):
        ns = {'svg': 'http://www.w3.org/2000/svg'}
        descriptions = set()
        for number in range(1, 40):
            svg = ET.parse(ROOT / f'assets/diagrams/TFA-{number:03}.svg').getroot()
            self.assertEqual(svg.attrib['role'], 'img')
            description = svg.find('svg:desc', ns).text
            self.assertGreater(len(description.split()), 20)
            descriptions.add(description)
        self.assertEqual(len(descriptions), 39)

    def test_oidc_teaching_example_is_inactive_and_scoped(self):
        text = (ROOT / 'labs/TFA-036/federation.workflow.yml.example').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:', text)
        self.assertIn('environment: azure-plan', text)
        self.assertIn('id-token: write', text)
        self.assertIn('az group show --subscription "$SUBSCRIPTION_ID" --name "$LAB_RESOURCE_GROUP"', text)
        self.assertNotIn('client-secret', text)
        self.assertNotIn('terraform apply', text)
        self.assertIn('token_exchange', (ROOT / 'labs/TFA-036/Test-FederationContract.ps1').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
