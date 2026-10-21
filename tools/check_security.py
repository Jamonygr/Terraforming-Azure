"""Focused training policy checks, not a substitute for a cloud security review."""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
issues=[]
tracked=subprocess.run(['git','ls-files','--cached','--others','--exclude-standard'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.splitlines()
for name in tracked:
    path=ROOT/name
    if not path.is_file():continue
    approved_stage = bool(re.fullmatch(r'labs/TFA-040/stages/(foundation|secure|applications|hybrid)\.tfvars',name))
    if path.suffix in ('.tfstate','.pfx','.pem','.key') or (name.endswith('.tfvars') and not approved_stage) or name.endswith('tfplan'):issues.append(f'{name}: sensitive generated file must not be tracked')
    if path.suffix in ('.tf','.ps1','.yml','.py','.json','.md'):
        text=path.read_text(encoding='utf-8')
        for pattern in (r'gh[pousr]_[A-Za-z0-9]{30,}',r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'):
            if re.search(pattern,text):issues.append(f'{name}: possible committed credential')
        if path.suffix=='.tf':
            # Match only the NIC resource, not NAT/Bastion public IP references elsewhere.
            for nic in re.findall(r'resource\s+"azurerm_network_interface"\s+"[^"]+"\s*\{(.*?)(?=\nresource |\noutput |\Z)',text,flags=re.S):
                if re.search(r'public_ip_address_id\s*=',nic):issues.append(f'{name}: VM public IP contradicts course private-VM policy')
            if re.search(r'(admin_password|certificate_password|vpn_shared_key)\s*=\s*"[^"$][^"]{7,}"',text):issues.append(f'{name}: possible hardcoded credential')
for issue in issues:print('FAIL '+issue)
if issues:raise SystemExit(1)
print('PASS: focused credential, generated-file and private-VM source policies. No live Azure security scan was performed.')
