"""Behavioral checks for authoritative metadata and stable quiz identity."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build_site import lesson_metadata, lesson_source, web_questions

class SiteGenerationTests(unittest.TestCase):
    def test_metadata_uses_current_catalog(self):
        first = {'id': 'TFA-001', 'title': 'First'}
        lab = {'id': 'TFA-002', 'title': 'Second', 'duration_minutes': 90, 'cost': 'None', 'run_mode': 'local', 'prerequisites': ['TFA-001']}
        lab['phase'] = 1
        catalog = {'labs': [first, lab], 'phases': [{'id': 1, 'title': 'Foundations'}]}
        rendered = lesson_metadata(lab, catalog)
        self.assertIn('90 minutes', rendered)
        self.assertIn('../TFA-001/README.md', rendered)
        self.assertIn('**Phase 1:** Foundations', rendered)
        lab.update(duration_minutes=120, prerequisites=[])
        changed = lesson_metadata(lab, catalog)
        self.assertIn('120 minutes', changed)
        self.assertNotIn('../TFA-001/', changed)

    def test_catalog_diagram_changes_update_source_without_changing_prose(self):
        lab = {'id': 'TFA-001', 'title': 'First', 'duration_minutes': 60, 'cost': 'None', 'run_mode': 'local', 'prerequisites': [], 'diagram': 'assets/diagrams/custom.svg'}
        catalog = {'labs': [lab]}
        original = '# First\n\n![Old](../../assets/diagrams/TFA-001.svg)\n\nAuthored explanation.\n'
        changed = lesson_source(original, lab, catalog)
        self.assertIn('../../assets/diagrams/custom.svg', changed)
        lab['diagram'] = 'assets/diagrams/replacement.svg'
        updated = lesson_source(changed, lab, catalog)
        self.assertNotIn('custom.svg', updated)
        self.assertIn('replacement.svg', updated)
        self.assertTrue(updated.endswith('Authored explanation.\n'))
        self.assertEqual(updated, lesson_source(updated, lab, catalog))

    def test_option_reordering_preserves_identity_and_revision(self):
        question = {'id': 'TFA-001-Q1', 'prompt': 'Choose', 'options': ['Wrong', 'Right', 'Other', 'Last'], 'answer': 1, 'explanation': 'Why this option is correct.'}
        original = web_questions([question])[0]
        reordered = copy.deepcopy(question)
        reordered.update(options=list(reversed(question['options'])), answer=2)
        transformed = web_questions([reordered])[0]
        self.assertEqual(original['answer'], transformed['answer'])
        self.assertEqual(original['revision'], transformed['revision'])
        reordered['prompt'] = 'Changed meaning'
        self.assertNotEqual(original['revision'], web_questions([reordered])[0]['revision'])

if __name__ == '__main__':
    unittest.main()
