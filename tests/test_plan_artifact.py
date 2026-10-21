import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone

ROOT=Path(__file__).resolve().parents[1]

class SavedPlanTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.plan=Path(self.temp.name)/'tfplan'; self.plan.write_bytes(b'synthetic unit-test plan')
        self.metadata=Path(self.temp.name)/'metadata.json'
        self.env={**os.environ,'GITHUB_SHA':'a'*40,'COURSE_STAGE':'applications','COURSE_OPERATION':'apply','TF_VAR_certificate_path':'/stable/lab.pfx'}
        self.assertEqual(self.run_tool('create').returncode,0)

    def run_tool(self,mode,env=None):
        return subprocess.run([sys.executable,str(ROOT/'tools/plan_artifact.py'),mode,str(self.plan),str(self.metadata)],env=env or self.env,capture_output=True,text=True)

    def test_same_plan_is_accepted(self):self.assertEqual(self.run_tool('verify').returncode,0)
    def test_tampered_binary_is_rejected(self):
        self.plan.write_bytes(b'changed plan')
        self.assertNotEqual(self.run_tool('verify').returncode,0)
    def test_wrong_commit_stage_operation_or_certificate_is_rejected(self):
        for key in ('GITHUB_SHA','COURSE_STAGE','COURSE_OPERATION','TF_VAR_certificate_path'):
            with self.subTest(key=key):self.assertNotEqual(self.run_tool('verify',{**self.env,key:'different'}).returncode,0)
    def test_old_and_future_plans_are_rejected(self):
        for offset in (-25,1):
            with self.subTest(offset=offset):
                data=json.loads(self.metadata.read_text());data['created']=(datetime.now(timezone.utc)+timedelta(hours=offset)).isoformat()
                self.metadata.write_text(json.dumps(data))
                self.assertNotEqual(self.run_tool('verify').returncode,0)

if __name__=='__main__':unittest.main()
