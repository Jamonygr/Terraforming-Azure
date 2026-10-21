"""Parse workflow intent without dispatching a job or obtaining an Azure token."""
from pathlib import Path
import unittest
import yaml

ROOT=Path(__file__).resolve().parents[1]


def workflow(name):
    # BaseLoader preserves YAML's 'on' key instead of treating it as a boolean.
    return yaml.load((ROOT/'.github/workflows'/name).read_text(),Loader=yaml.BaseLoader)


class WorkflowPolicyTests(unittest.TestCase):
    def test_cloud_lifecycle_is_manual_and_unconfigured_before_login(self):
        doc=workflow('azure.yml')
        self.assertEqual(list(doc['on']),['workflow_dispatch'])
        for job in doc['jobs'].values():
            self.assertIn("github.ref == 'refs/heads/main'",job['if'])
            self.assertIn(job['environment'],['azure-plan','azure-course'])
            login=next(i for i,s in enumerate(job['steps']) if s.get('uses','').startswith('azure/login@'))
            self.assertTrue(any('AZURE_WORKFLOW_READY' in s.get('run','') for s in job['steps'][:login]))

    def test_quality_has_windows_and_no_cloud_auth(self):
        doc=workflow('quality.yml')
        self.assertEqual(doc['jobs']['validate']['runs-on'],'ubuntu-24.04')
        self.assertEqual(doc['jobs']['windows']['runs-on'],'windows-2025')
        for job in doc['jobs'].values():
            self.assertIn('timeout-minutes',job)
            self.assertFalse(any(s.get('uses','').startswith('azure/') for s in job['steps']))

    def test_pages_only_consumes_trusted_successful_main_artifact(self):
        doc=workflow('pages.yml')
        self.assertEqual(list(doc['on']),['workflow_run'])
        gate=doc['jobs']['prepare']['if']
        for condition in ["conclusion == 'success'","head_branch == 'main'","head_repository.full_name == github.repository","event == 'push'"]:
            self.assertIn(condition,gate)
        download=next(s for s in doc['jobs']['prepare']['steps'] if s.get('uses','').startswith('actions/download-artifact@'))
        self.assertEqual(download['with']['run-id'],'${{ github.event.workflow_run.id }}')
        self.assertEqual(download['with']['name'],'learning-site')

    def test_all_actions_are_pinned_to_commit(self):
        for file in (ROOT/'.github/workflows').glob('*.yml'):
            for job in workflow(file.name)['jobs'].values():
                for step in job.get('steps',[]):
                    if 'uses' in step:self.assertRegex(step['uses'],r'^[\w.-]+/[\w.-]+@[a-f0-9]{40}$')


if __name__=='__main__':unittest.main()
