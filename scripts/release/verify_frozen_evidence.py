#!/usr/bin/env python3
"""Verify a frozen baseline evidence directory, not a scientific rebuild. No training/installation."""
import argparse
import csv
from decimal import Decimal
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
ROOT=Path(__file__).resolve().parents[2]
M1='Results/baseline_ml/run-20261026T073318Z-86649'
R1='Results/baseline_manuscript_ml/run-20261026T113840Z-17527'
ARCHIVE='wgcna/wgcna-20261024T171133Z-54144.tar.gz'
def safe_path(name):
    p=PurePosixPath(name)
    if (not name or p.is_absolute() or '..' in p.parts or p.as_posix()!=name or
        '\\' in name or ':' in name or any(ord(c)<32 or ord(c)==127 for c in name)):
        raise ValueError('Unsafe relative path: '+name)
    return p
def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def byte_count(text):
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',text) or len(text)>128:
        raise ValueError('Invalid byte count')
    v=Decimal(text)
    if not v.is_finite() or v<0 or v!=v.to_integral_value() or v>2**63-1:raise ValueError('Invalid byte count')
    return int(v)
def verify_inventory(bundle,manifest):
    if manifest.get('format')!='baseline-frozen-evidence-v1' or not manifest.get('files'):raise ValueError('Invalid inventory')
    actual=set()
    for p in bundle.rglob('*'):
        if p.is_symlink():raise ValueError('Symlink in frozen layout')
        if p.is_dir():continue
        if not p.is_file():raise ValueError('Special file in frozen layout')
        actual.add(p.relative_to(bundle).as_posix())
    if actual!=set(manifest['files'])|{'BUNDLE.json'}:raise ValueError('Bundle file set mismatch')
    for name,entry in manifest['files'].items():
        path=bundle/safe_path(name)
        if not isinstance(entry['bytes'],int) or entry['bytes']<0 or not re.fullmatch('[0-9a-f]{64}',entry['sha256']):
            raise ValueError('Invalid frozen entry')
        if path.stat().st_size!=entry['bytes'] or sha(path)!=entry['sha256']:raise ValueError('Corrupted frozen file: '+name)

def verify_run(run,expected_status,expected_models):
    report=json.loads((run/'review-finalization.json').read_text())
    manifest=run/'artifact_checksums.csv'
    if sha(manifest)!=report['artifact_manifest_sha256']:raise ValueError('ML finalisation manifest hash mismatch')
    if report['workflow_status']!=expected_status or report['models']!=expected_models:raise ValueError('Unexpected ML classification')
    if (run/'COMPLETED').exists():raise ValueError('Unexpected analysis-success marker')
    with manifest.open(newline='') as f:
        reader=csv.reader(f);header=next(reader)
        indexed=header==['','path','bytes','sha256']
        if header!=['path','bytes','sha256'] and not indexed:raise ValueError('Unexpected manifest header')
        entries={}
        for row in reader:
            if indexed:
                if len(row)!=4 or row[0]!=row[1]:raise ValueError('Invalid R path row index')
                row=row[1:]
            if len(row)!=3:raise ValueError('Invalid manifest row')
            name,size,digest=row;safe_path(name)
            if name in entries or name in ('artifact_checksums.csv','review-finalization.json'):raise ValueError('Duplicate/self reference')
            p=run/name
            if p.stat().st_size!=byte_count(size) or sha(p)!=digest:raise ValueError('ML manifest corruption: '+name)
            entries[name]=digest
    actual={p.relative_to(run).as_posix() for p in run.rglob('*') if p.is_file()}
    if actual!=set(entries)|{'artifact_checksums.csv','review-finalization.json'}:raise ValueError('ML unlisted/missing files')
    return dict(workflow_status=report['workflow_status'],models=report['models'],
        diagnostic_status=report.get('diagnostic_status','not_applicable'),verified_artifacts=len(entries))

def check_locks(repo):
    folder=repo/'release/baseline-rc1/environments'
    baseline=json.loads((repo/'renv.lock').read_text())
    manu=json.loads((folder/'manu-renv.lock').read_text())
    manuscript=json.loads((folder/'manuscript-renv.lock').read_text())
    if (len(baseline['Packages']),len(manu['Packages']),len(manuscript['Packages']))!=(113,149,150):raise ValueError('Lock counts changed')
    for parent,child in [(baseline,manu),(manu,manuscript)]:
        if parent['R']!=child['R'] or parent['Bioconductor']!=child['Bioconductor']:raise ValueError('Environment metadata changed')
        for package,value in parent['Packages'].items():
            if child['Packages'].get(package)!=value:raise ValueError('Retained lock record changed: '+package)
    review=json.loads((folder/'xgboost-api-review.json').read_text())
    if manuscript['Packages']['xgboost']['Version']!=review['version'] or review['version']!='1.7.11.1':raise ValueError('XGBoost record mismatch')
    return dict(baseline=113,manu=149,manuscript=150,xgboost=review['version'])

def verify(bundle,expected_path):
    manifest=json.loads(expected_path.read_text())
    if (bundle/'BUNDLE.json').read_bytes()!=expected_path.read_bytes():raise ValueError('Bundle is not the reviewed frozen inventory')
    verify_inventory(bundle,manifest)
    repo=bundle/'repository'
    result=dict(acceptance='frozen_evidence_only',integrity='verified',
        clean_clone_rebuild='not_established',scientific_validation='not_established',
        files=len(manifest['files']),payload_bytes=sum(x['bytes'] for x in manifest['files'].values()),locks=check_locks(repo))
    refs=json.loads((repo/'release/baseline-rc1/environments/xgboost-build-references.json').read_text())
    for name,entry in refs['files'].items():
        if manifest['files'].get(name)!=entry:raise ValueError('XGBoost source/build reference not preserved: '+name)
    result['M1']=verify_run(repo/M1,'finished_with_model_failure',dict(RF='succeeded',SVM='succeeded',logistic='training_failed'))
    result['R1']=verify_run(repo/R1,'finished_all_models_succeeded',dict(RF='succeeded',SVM='succeeded',LR='succeeded',XGB='succeeded'))
    if result['R1']['diagnostic_status']!='review_required':raise ValueError('SVM/XGB diagnostic limitation lost')
    # Read base-R provenance only. Never source a stage runner or load fitted models.
    subprocess.run(['Rscript','--vanilla','-e',
        'stopifnot(identical(readRDS(commandArgs(TRUE)[1])$status,"completed"))',
        str(repo/'Results/baseline_preprocessing/run-20261013T053229Z-205981/execution_provenance.rds')],check=True,capture_output=True,text=True)
    result['preprocessing']='completed_saved_provenance'
    spec=importlib.util.spec_from_file_location('release_patient_audit',Path(__file__).with_name('patient_overlap.py'))
    audit_module=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit_module)
    patient,memberships=audit_module.audit(repo,Path(__file__).with_name('export_saved_splits.R'))
    frozen=json.loads((repo/'release/baseline-rc1/patient-audit/patient-overlap.json').read_text())
    if patient!=frozen:raise ValueError('Saved patient audit does not match recomputation from saved IDs')
    with (repo/'release/baseline-rc1/patient-audit/split-membership.csv').open(newline='') as f:
        preserved=list(csv.DictReader(f))
    if preserved!=[{k:str(v) for k,v in row.items()} for row in memberships]:raise ValueError('Patient membership export changed')
    result['patient_overlap']={k:{field:v[field] for field in ['known_shared_patient_count','unknown_patient_counts']}
                               for k,v in patient['runs'].items()}
    with tempfile.TemporaryDirectory(prefix='frozen-wgcna-verify-') as temp:
        report=Path(temp)/'verification.json'
        proc=subprocess.run([sys.executable,str(bundle/'tooling/retrieval/verify.py'),str(bundle/ARCHIVE),
            '--sha256-file',str(bundle/(ARCHIVE+'.sha256')),'--report',str(report)],capture_output=True,text=True)
        if not report.is_file():raise ValueError('Archive verifier did not produce a report: '+proc.stderr[-1000:])
        wgcna=json.loads(report.read_text())
        if (proc.returncode!=3 or wgcna.get('transfer_integrity')!='verified' or
            wgcna.get('classification')!='incomplete' or wgcna.get('monitoring_status')!='complete' or
            len(wgcna.get('runs',[]))!=1 or wgcna['runs'][0]['run']!='run-20261024T120729Z-46759' or
            not wgcna['runs'][0]['manifest_present'] or wgcna['runs'][0]['verified_artifact_entries']!=27):
            raise ValueError('WGCNA archive integrity/classification/monitoring checks failed: '+str(wgcna))
    result['WGCNA']=dict(classification='incomplete',verified_artifacts=27,monitoring_status='complete',
        aggregate_memory_peak_bytes=wgcna['monitoring']['final_aggregate_memory_peak_bytes'])
    # Verify preservation of recovery source/backup and deployed definitions in the
    # already hash-verified archive, without extracting any network object.
    package=None
    with tarfile.open(bundle/ARCHIVE,'r|gz') as archive:
        for member in archive:
            if member.name=='PACKAGE.json':
                if member.size>16*2**20:raise ValueError('Oversized archive inventory')
                package=json.load(archive.extractfile(member));break
    if not package:raise ValueError('Missing archive preservation inventory')
    names=package['files']
    for suffix in ['deployed-helper/monitor.py','deployed-units/wgcna-analysis.service',
        'deployed-units/wgcna-supervisor.service','deployed-units/wgcna-keeper.service',
        'deployed-units/wgcna.slice','recovery-source/patched-recovery.R','recovery-source/recovery-backup.R']:
        if not any(name.endswith('/'+suffix) for name in names):raise ValueError('Missing archived tooling: '+suffix)
    result['preservation']='required local payload and archived deployed/recovery tooling verified; off-host custody not established'
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle',type=Path)
    parser.add_argument('--expected-manifest',type=Path,default=ROOT/'release/baseline-rc1/evidence-manifest.json')
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if args.report and args.report.exists():parser.error('Report must be new; no overwrites')
    try:result=verify(args.bundle.resolve(),args.expected_manifest.resolve());status=0
    except Exception as error:result=dict(integrity='FAILED',error=str(error),acceptance='not_met');status=1
    text=json.dumps(result,indent=2)+'\n'
    if args.report:
        with args.report.open('x') as f:f.write(text)
    print(text,end='');return status
if __name__=='__main__':sys.exit(main())
