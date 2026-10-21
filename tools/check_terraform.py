"""Credential-free validation of every independent example; never plan/apply Azure."""
from pathlib import Path
import argparse
import concurrent.futures
import os
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def roots():
    result=[]
    for base in ('labs','bootstrap','modules'):
        for file in (ROOT/base).rglob('*.tf'):
            if '.terraform' in file.parts:continue
            folder=file.parent
            if folder not in result and (base!='modules' or (folder/'tests').is_dir()):result.append(folder)
    return sorted(result)

def check(folder,skip_tests):
    relative=folder.relative_to(ROOT).as_posix()
    commands=[['terraform','init','-backend=false','-input=false','-lockfile=readonly','-no-color'],['terraform','validate','-no-color']]
    if not skip_tests and (folder/'tests').is_dir():commands.append(['terraform','test','-no-color'])
    for command in commands:
        result=subprocess.run(command,cwd=folder,capture_output=True,text=True,encoding='utf-8',errors='replace',env={**os.environ,'TF_IN_AUTOMATION':'true'})
        if result.returncode:return relative,False,result.stdout+result.stderr
    return relative,True,f'{len(commands)} checks'

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--skip-tests',action='store_true');parser.add_argument('--jobs',type=int,default=1)
    args=parser.parse_args();failed=[]
    folders=roots()
    # A shared plugin cache should be prewarmed, or use --jobs 1 on the first run.
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures=[pool.submit(check,p,args.skip_tests) for p in folders]
        for future in concurrent.futures.as_completed(futures):
            relative,ok,detail=future.result()
            print(('PASS ' if ok else 'FAIL ')+relative,flush=True)
            if not ok:print(detail,flush=True);failed.append(relative)
    print(f'{len(folders)-len(failed)}/{len(folders)} Terraform roots passed. Azure deployments were not run.')
    if failed:raise SystemExit(1)

if __name__=='__main__':main()
