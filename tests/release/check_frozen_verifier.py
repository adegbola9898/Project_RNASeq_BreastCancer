#!/usr/bin/env python3
"""Small integrity/admission fixtures; no models, installs or analysis reruns."""
import csv
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
v=load('frozen',ROOT/'scripts/release/verify_frozen_evidence.py')
a=load('overlap',ROOT/'scripts/release/patient_overlap.py')
def rejected(callback):
    try: callback()
    except (ValueError,FileNotFoundError):return
    raise AssertionError('Expected rejection')
for name in ['../x','/tmp/x','x/../y','a\\b','a:b','x//y','x\n']:
    rejected(lambda:v.safe_path(name))
assert v.byte_count('1e+05')==100000
for text in ['-1','.5','NaN','Infinity','1.1','1e-2']:rejected(lambda:v.byte_count(text))
with tempfile.TemporaryDirectory(prefix='frozen-tests-') as tmp:
    b=Path(tmp);p=b/'artifact';p.write_bytes(b'x'*100000);(b/'BUNDLE.json').write_text('{}')
    manifest=dict(format='baseline-frozen-evidence-v1',files={'artifact':dict(bytes=100000,sha256=v.sha(p))})
    v.verify_inventory(b,manifest)
    p.write_bytes(b'bad');rejected(lambda:v.verify_inventory(b,manifest));p.write_bytes(b'x'*100000)
    (b/'extra').write_text('unexpected');rejected(lambda:v.verify_inventory(b,manifest));(b/'extra').unlink()
    (b/'link').symlink_to(p);rejected(lambda:v.verify_inventory(b,manifest));(b/'link').unlink()
    with (b/'artifact_checksums.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['','path','bytes','sha256']);w.writerow(['artifact','artifact','1e+05',v.sha(p)])
    (b/'BUNDLE.json').unlink()
    record=dict(workflow_status='finished_with_model_failure',models={'RF':'succeeded','LR':'training_failed'},
        artifact_manifest_sha256=v.sha(b/'artifact_checksums.csv'))
    (b/'review-finalization.json').write_text(json.dumps(record))
    v.verify_run(b,record['workflow_status'],record['models'])
    rejected(lambda:v.verify_run(b,'finished_all_models_succeeded',record['models']))
    (b/'COMPLETED').write_text('false success');rejected(lambda:v.verify_run(b,record['workflow_status'],record['models']))
print('PASS verifier fixtures: safe paths, exact byte counts, corrupt/extra/link files, real-R path index, honest mixed status, forbidden success marker')
with (ROOT/'release/baseline-rc1/patient-audit/split-membership.csv').open(newline='') as f:rows=list(csv.DictReader(f))
with (ROOT/'Data/Manifests/sample_provenance.csv').open(newline='') as f:provenance=list(csv.DictReader(f))
r,_=a.audit_rows(rows,provenance)
assert [r['runs'][x]['known_shared_patient_count'] for x in ('M1','R1')]==[28,31]
for run in r['runs'].values():assert run['unknown_patient_counts']==dict(train=88,test=33)
rejected(lambda:a.audit_rows(rows[:-1],provenance))
rejected(lambda:a.audit_rows(rows,provenance+[provenance[0]]))
print('PASS patient fixtures: shared groups and unknown identity retained; incomplete split and duplicate provenance rejected')
