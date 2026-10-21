"""Bind a saved plan to commit/stage/operation and reject tampering/staleness."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import sys

plan=Path(sys.argv[2]); metadata=Path(sys.argv[3])
digest=lambda:hashlib.sha256(plan.read_bytes()).hexdigest()
if sys.argv[1]=='create':
    metadata.write_text(json.dumps({'sha256':digest(),'commit':os.environ['GITHUB_SHA'],
        'stage':os.environ['COURSE_STAGE'],'operation':os.environ['COURSE_OPERATION'],
        'certificate_path':os.environ.get('TF_VAR_certificate_path',''),
        'created':datetime.now(timezone.utc).isoformat()},indent=2),encoding='utf-8')
elif sys.argv[1]=='verify':
    data=json.loads(metadata.read_text(encoding='utf-8'))
    for field,expected in [('sha256',digest()),('commit',os.environ['GITHUB_SHA']),('stage',os.environ['COURSE_STAGE']),('operation',os.environ['COURSE_OPERATION'])]:
        if data[field]!=expected:raise SystemExit(f'Plan {field} mismatch. Create and review a fresh plan.')
    if data.get('certificate_path','')!=os.environ.get('TF_VAR_certificate_path',''):
        raise SystemExit('Plan certificate path differs from this runner. Recreate and review the plan with a stable certificate path.')
    age=(datetime.now(timezone.utc)-datetime.fromisoformat(data['created'])).total_seconds()
    if age<0 or age>86400:raise SystemExit('Plan expired. Create and review a fresh plan.')
    print('PASS saved-plan identity, integrity and age.')
else:raise SystemExit('Use create or verify.')
