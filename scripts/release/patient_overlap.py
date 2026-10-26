#!/usr/bin/env python3
"""Audit saved ML memberships against reported GEO patient IDs; never infer independence."""
import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

SPLITS = {
 'M1': 'Results/baseline_ml/run-20261026T073318Z-86649/split.rds',
 'R1': 'Results/baseline_manuscript_ml/run-20261026T113840Z-17527/faithful/split.rds',
}
MANIFEST = 'Data/Manifests/sample_provenance.csv'
def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()
def audit_rows(rows, provenance):
    by_id = {}
    for record in provenance:
        sid = record['sample_id']
        if sid in by_id or not sid or sid.strip() != sid:
            raise ValueError('Duplicate/invalid provenance sample ID')
        by_id[sid] = record
    included = {sid for sid, r in by_id.items() if r['included_in_final_metadata'].lower() == 'true'}
    summaries, memberships = {}, []
    for run in SPLITS:
        selected = [r for r in rows if r['run'] == run]
        parts = {p:[r['sample_id'] for r in selected if r['partition'] == p] for p in ('train','test')}
        if (len(parts['train']) != 198 or len(parts['test']) != 81 or
            set(parts['train']) & set(parts['test']) or
            len(set(parts['train'] + parts['test'])) != 279 or
            set(parts['train'] + parts['test']) != included):
            raise ValueError('Saved split membership/coverage mismatch: ' + run)
        groups, unknown, dataset_unknown = {}, {}, {}
        for partition, ids in parts.items():
            groups[partition], unknown[partition], dataset_unknown[partition] = {}, [], Counter()
            for position, sid in enumerate(ids, 1):
                record = by_id[sid]
                group = record['patient_group_id']
                known = bool(group) and bool(record['patient_id']) and record['patient_id_status'] == 'reported'
                if group and not known:
                    raise ValueError('Inconsistent patient annotation: ' + sid)
                if known:
                    if group != record['dataset'] + ':' + record['patient_id']:
                        raise ValueError('Patient group is not dataset-qualified: ' + sid)
                    groups[partition].setdefault(group, []).append(sid)
                else:
                    unknown[partition].append(sid)
                    dataset_unknown[partition][record['dataset']] += 1
                memberships.append(dict(run=run,partition=partition,position=position,sample_id=sid,
                    dataset=record['dataset'],patient_group_id=group if known else '',
                    patient_identity='reported' if known else 'unknown'))
        shared = sorted(set(groups['train']) & set(groups['test']))
        summaries[run] = dict(train_samples=len(parts['train']),test_samples=len(parts['test']),
            known_shared_patient_count=len(shared),
            shared_patients={g:dict(train=groups['train'][g],test=groups['test'][g]) for g in shared},
            samples_in_shared_patients={p:sum(len(groups[p][g]) for g in shared) for p in parts},
            known_patient_counts={p:len(groups[p]) for p in parts},
            unknown_patient_samples=unknown,
            unknown_patient_counts={p:len(unknown[p]) for p in parts},
            unknown_by_dataset={p:dict(sorted(dataset_unknown[p].items())) for p in parts})
    return dict(runs=summaries, interpretation='Known cross-split patients are leakage evidence. Unknown patient identity never establishes independence.'), memberships

def audit(root, exporter):
    with tempfile.TemporaryDirectory(prefix='baseline-patient-audit-') as temp:
        csv_path = Path(temp)/'split-ids.csv'
        subprocess.run(['Rscript','--vanilla',str(exporter),*[str(root/p) for p in SPLITS.values()],str(csv_path)],check=True)
        with csv_path.open(newline='') as f:
            rows = list(csv.DictReader(f))
    with (root/MANIFEST).open(newline='') as f:
        provenance = list(csv.DictReader(f))
    report, memberships = audit_rows(rows,provenance)
    report['input_sha256'] = {p:sha(root/p) for p in [MANIFEST,*SPLITS.values()]}
    return report, memberships

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report,memberships=audit(args.root.resolve(),Path(__file__).with_name('export_saved_splits.R'))
    args.output.mkdir(parents=True,exist_ok=False)
    (args.output/'patient-overlap.json').write_text(json.dumps(report,indent=2)+'\n')
    with (args.output/'split-membership.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(memberships[0]));writer.writeheader();writer.writerows(memberships)
    print(json.dumps({run:{k:v for k,v in r.items() if k not in ('shared_patients','unknown_patient_samples')}
        for run,r in report['runs'].items()},indent=2))
if __name__=='__main__': main()
