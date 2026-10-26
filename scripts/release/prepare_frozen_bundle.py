#!/usr/bin/env python3
"""Copy existing evidence into a new portable directory; never run analysis or stop services."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
RC=ROOT/'release/baseline-rc1'
def sha(path):
    with path.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination',type=Path)
    args=parser.parse_args()
    destination=args.destination.resolve()
    manifest_path=RC/'evidence-manifest.json'
    if destination.exists() or manifest_path.exists(): raise ValueError('Destination and frozen manifest must be new')
    sources={}
    def add(source,target,expected=None):
        source=source.absolute()
        if source.is_symlink() or not source.is_file(): raise ValueError('Not a regular source: '+str(source))
        if target in sources and sources[target][0] != source: raise ValueError('Duplicate target: '+target)
        sources[target]=(source,expected)
    for line in (ROOT/'docs/baseline-release-inventory.sha256').read_text().splitlines():
        match=re.fullmatch(r'([0-9a-f]{64})  (.+)',line)
        if not match: continue
        value,name=match.groups();source=Path(name)
        if not source.is_absolute(): target='repository/'+source.as_posix();source=ROOT/source
        elif source.is_relative_to(Path('/home/samuel/env-records')):
            target='dependencies/'+source.relative_to('/home/samuel/env-records').as_posix()
        elif source.is_relative_to(Path('/home/samuel/wgcna-evidence-20261024')):
            target='wgcna/'+source.relative_to('/home/samuel/wgcna-evidence-20261024').as_posix()
        else: raise ValueError('Unreviewed external input: '+str(source))
        add(source,target,value)
    # Snapshot current release instructions/code plus original input evidence.
    for folder in ['scripts','tests','docs','release/baseline-rc1','notebooks/original']:
        for p in sorted((ROOT/folder).rglob('*')):
            if p.is_dir(): continue
            if '__pycache__' in p.parts or p.suffix=='.pyc' or p.name.endswith(':Zone.Identifier'): continue
            if p.name in ('evidence-manifest.json','verification-result.json'): continue
            target='repository/'+p.relative_to(ROOT).as_posix()
            if target not in sources: add(p,target)
    for name in ['AGENTS.md','CLAUDE.md','README.md','.gitignore','renv.lock','renv/settings.json',
                 'renv/activate.R','.Rprofile','Data/Manifests/sample_provenance.csv',
                 'Data/Processed/metadata.csv','Data/Processed/updated_count_matrix (1).csv']:
        add(ROOT/name,'repository/'+name)
    for tool in ('monitoring','retrieval'):
        base=Path.home()/('wgcna-cloud-'+tool)
        for p in sorted(base.iterdir()):
            if p.is_file() and p.suffix in ('.py','.sh','.md','.txt'): add(p,'tooling/'+tool+'/'+p.name)
    destination.mkdir(parents=True,exist_ok=False)
    files={}
    for target,(source,expected) in sorted(sources.items()):
        before=source.stat()
        out=destination/target;out.parent.mkdir(parents=True,exist_ok=True)
        with source.open('rb') as src,out.open('xb') as dst: shutil.copyfileobj(src,dst,1024*1024)
        value=sha(out);after=source.stat()
        if (before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise ValueError('Source changed during preservation: '+str(source))
        if expected and value!=expected: raise ValueError('Source differs from prior inventory: '+str(source))
        files[target]={'bytes':out.stat().st_size,'sha256':value}
    result=dict(format='baseline-frozen-evidence-v1',
        meaning='Archived evidence verification only; not a clean-clone end-to-end rebuild or independent validation.',
        implementation_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        working_tree_snapshot=True,files=files)
    text=json.dumps(result,indent=2,sort_keys=True)+'\n'
    with (destination/'BUNDLE.json').open('x') as f:f.write(text)
    with manifest_path.open('x') as f:f.write(text)
    print(json.dumps(dict(bundle=str(destination),files=len(files),payload_bytes=sum(x['bytes'] for x in files.values()),
        manifest_sha256=hashlib.sha256(text.encode()).hexdigest()),indent=2))
if __name__=='__main__':main()
