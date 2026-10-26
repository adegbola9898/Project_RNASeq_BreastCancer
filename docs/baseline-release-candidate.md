# Baseline release candidate RC1

## Narrowed acceptance and entry point

The release entry point is **one command verifying frozen archived evidence**:

```sh
python3 scripts/release/verify_frozen_evidence.py Results/baseline_release/rc1
```

Run from this checkout, or replace the final argument with the relocated bundle
directory. Requires Python 3.11+ and base R/Rscript 4.5.2 on PATH; it uses
`Rscript --vanilla` only to read saved split/provenance RDS, not project packages,
runners, models or workspaces. No network, installation, fitting, provisioning or
stage execution occurs. A trusted checkout supplies the expected manifest at
`release/baseline-rc1/evidence-manifest.json`; bundle BUNDLE.json must match it
exactly. Do not replace the trusted manifest with one from an untrusted download.

Exit 0 means every required frozen file/hash/manifest/classification and the
saved-ID patient audit passed. Exit 1 means verification failed; usage errors
exit 2. Exit 0 **does not mean** that all original runs completed, that historical
sessions were recovered, that the manuscript is scientifically validated, or that
a clean clone can rebuild end to end. This narrower acceptance is explicit and
supersedes the draft inventory's open choice between rebuild and verification.

The verifier checks: exact portable file set, byte counts and SHA-256; both ML
stage manifests and their audit-record manifest hashes; baseline/ML lock subset
identity (113→149→150); XGBoost source/build references; completed preprocessing
provenance; original WGCNA archive inventory/artifact hashes, incomplete status
and monitoring/OOM/aggregate peak evidence; archived deployed units/helper and
recovery script/backup; and the patient audit recomputed from saved IDs. It never
extracts/loads the TOM or refits a model. The archive verification streams bytes.

A frozen manifest authenticates against the trusted release checkout; it is not
a digital signature or proof of data origin. Audit finalisation records are not
analysis-success markers. The WGCNA archive verifier's expected exit 3 is accepted
only with an actual valid report, verified integrity, incomplete classification,
27 verified artifact entries and complete monitoring evidence.

## Patient-overlap audit (saved memberships only)

See exact [JSON report](../release/baseline-rc1/patient-audit/patient-overlap.json)
and [558 ordered membership rows](../release/baseline-rc1/patient-audit/split-membership.csv).
Source: each original split.rds and Data/Manifests/sample_provenance.csv; their
hashes are recorded in the JSON. No split or feature selection was recomputed.
Dataset-qualified patient_group_id is used only when the patient ID is reported.
All split samples map uniquely to included provenance rows; each saved split has
198 training and 81 test IDs, disjoint as samples, covering exactly the 279.

| Run | Known patients on both sides | Training/test samples belonging to these shared patients | Unknown patient samples (train/test) |
| --- | ---: | --- | --- |
| M1 Manu | 28 | 28 / 28 | 88 / 33 |
| R1 manuscript | 31 | 31 / 31 | 88 / 33 |

Every shared group is GSE243375-qualified. M1 shared patient IDs are:
114, 115, 117, 120, 123, 131, 136, 144, 147, 149, 154, 158, 161, 28,
35, 37, 38, 47, 58, 74, 80, 81, 84, 86, 87, 92, 93, 98.
R1 shared IDs are: 102, 114, 115, 120, 126, 128, 131, 136, 141, 144,
147, 153, 154, 157, 158, 160, 24, 36, 38, 47, 50, 58, 59, 72, 82,
87, 89, 91, 93, 98, 99. The JSON enumerates their exact train/test sample IDs.

Unknown identity comprises all 121 selected samples from GSE52194/GSE58135:
M1 train10/78, test1/32 respectively; R1 train8/80, test3/30 respectively.
Known cross-split patient sharing is direct leakage evidence. Unknown identity
never establishes independence, nor does lack of a shared reported ID establish
independence among all remaining samples. Corrected patient/study-aware validation
is separate future work. The parked historical sample-count issue is not reopened.

## Accepted baseline dispositions

As directed by the release request, the following are accepted **for a documented
baseline release**, not repaired, promoted to validation or treated as rerun gates:

- Conflicting historical RF/SVM AUC sets: preserve ML71/72 and ML120 without
  choosing an authoritative history or inventing a cause. R1 matches ML120 at
  reported precision; source checkpoint comparisons against ML71/72 can differ.
- SVM defect: preserve R1's positional source AUCs and observed probability-column
  mismatch. A corrected named-column evaluation is not silently substituted.
- Original WGCNA attempt stays incomplete/exit1. All analytical stages finished;
  the required PNG was missing. The audit and separately recovered heatmap are
  retained; no original manifest, provenance or COMPLETED state is changed.
- Unsupported clinical/independent-validation and literature/enrichment claims
  remain unsupported. C03 numerical PCA details remain qualified where not
  established; C04/C06/C10/C11/C15 method/number discrepancies stay recorded.
  Baseline closure does not approve those claims or change the manuscript.
- Lost external Manu console/time logs remain lost. The surviving in-run log,
  provenance/process records, saved models/predictions, verified 31-file manifest
  and audit record support the accepted M1 mixed outcome. The dependency bundle's
  NOTE.txt documents loss; no reconstructed external logs or inferred timings.
- The new patient-overlap results strengthen the existing leakage limitation;
  they do not trigger refitting the faithful baseline.

Honest frozen classifications: preprocessing completed; WGCNA incomplete with
separate recovered visualization; M1 finished_with_model_failure (RF/SVM succeeded,
caret LR training_failed); R1 finished_all_models_succeeded **with review_required
probability diagnostics**. These are explicitly not all-model, all-stage success.

## Portable layout and custody

The local bundle is an ordinary relocatable directory:

```text
rc1/BUNDLE.json                       frozen inventory, matched to trusted Git copy
rc1/repository/Results/...            original preprocessing and both ML runs
rc1/repository/Data/...               count/metadata inputs and sample provenance
rc1/repository/notebooks/original/... preserved original notebooks
rc1/repository/scripts,docs,tests/...  source/instructions at RC preparation
rc1/repository/release/baseline-rc1/   exact locks/review references and patient audit
rc1/wgcna/...                         original full WGCNA archive, review/audit/recovery,
                                     recovered Machine_Learn notebook/manuscript PDF
rc1/dependencies/...                  both dependency bundles, source tarballs,
                                     successful/failed build and surviving run logs
rc1/tooling/monitoring/...            current prepared monitoring scripts/README/checks
rc1/tooling/retrieval/...             reviewed archive/download verifiers and helpers
```

The original WGCNA archive separately contains actual deployed systemd units,
monitor.py, effective definitions, monitoring counters and the patched recovery
script plus backup. Preserve that archive; current preparation scripts do not
replace the deployed record. No Zone.Identifier, cache, credentials or extracted
XGBoost source trees are added. Source tarballs preserve those source versions.
The exact ML locks/API review/findings and build-reference hashes are small and
version controlled under release/baseline-rc1/environments/. Large results and the
portable bundle are ignored by Git. The legacy 207-entry inventory is retained
as a source checksum record; the new frozen inventory uses portable paths.

Prepare a new candidate locally with the explicit, non-analysis command below
**only when its destination and frozen-manifest output do not already exist**:

```sh
python3 scripts/release/prepare_frozen_bundle.py Results/baseline_release/rc1
```

It copies existing files and rejects source hash/change mismatches; it does not
retrieve data, stop services or recreate outputs. It refuses to overwrite this
candidate. It is a local preparation utility for the known source locations,
not a public downloader. Its partial output on failure is not a valid release.

For transport, preserve the whole directory (or a regular tar archive containing
it), BUNDLE.json, the trusted checkout manifest and its independently recorded
hash. Check the archive SHA-256 before unpacking; safely restore ordinary files
without traversal/symlinks into a new location, then run the verifier. Local
packaging/checksums are integrity evidence, not a custodial backup policy.

**Preservation policy (clarified 26 October 2026 after Claude's RC review):** an
off-host second copy is **recommended but not required** for this scoped release.
Current custody, stated as is: one verified local bundle at
`Results/baseline_release/rc1/` on the preparation workstation, matching the
trusted manifest (SHA-256
`ba5e98ea97f4b59cfdf870a6a473aa1a395741e08f686313fcf508ab7c6b367f`); **no
off-host copy, archival custodian/retention owner, public deposit or retrieval URL
is established.** No public location is invented, and no evidence was transferred
or deleted. Until a second copy exists, loss of this workstation loses the large
evidence.
A recipient must be supplied the actual private archive/directory and trusted
manifest through an approved channel. Verify its transport hash and rerun the
entry point on the receiving copy before considering deletion of any source.
No cleanup/deletion, transfer, push or tag is authorised here. If source locations
are lost before that copy exists, Git alone does not contain the large evidence.

The release verifier and hashes establish preservation/integrity of the selected
payload, not reproducibility of the complete historical software build. Original
Manu external logs cannot be recovered; that permanent limitation is accepted.
Original live WGCNA objects unavailable to the audit remain unavailable.

## Separate stage replay instructions

[Stage replay](baseline-stage-replay.md) remains distinct. It is not invoked by
the release entry point and requires separate execution/resource authorisation.
The named preprocessing bridge prevents automatic fresh-run chaining; no clean
clone end-to-end rebuild claim is made or required for this candidate.

## Finite RC checklist

- [x] Read-only saved-ID patient audit for both ML runs; known sharing and unknown
  identity recorded with exact source hashes, group IDs and membership rows.
- [x] Exact 149/150-record ML locks and XGBoost review/findings/build references
  preserved at version-controlled release paths without altering baseline records.
- [x] Narrow acceptance defined as one-command frozen-evidence verification;
  stage replay and clean-clone limitations documented separately.
- [x] Accepted historical contradictions, source defects, incomplete WGCNA,
  unsupported claims and lost external Manu logs retained honestly.
- [x] Portable local layout and verifier implemented; authoritative local verdict
  is recorded in release/baseline-rc1/verification-result.json. A checkbox is not
  an all-stage-success marker.
- [x] Claude independently reviews the RC code, payload inventory and dispositions
  (26 October 2026: no release blockers; real verifier exit 0; corruption,
  missing-file, unlisted-file, status and BUNDLE.json tampering rejected).
- [ ] Recommended, not required for this scoped release: assign an archival
  custodian/retention destination and verify a second copy after approved
  transfer. Not established; no deposit or location assumed.
- [x] Commit authority granted for the reviewed release records. Push/tag remain
  separately authorised. No publication or corrected-validation claim follows
  automatically from baseline acceptance.

This document was clarified after the frozen bundle was prepared. The bundle's
`repository/docs/` copy keeps the earlier wording; the frozen payload and
trusted manifest were not regenerated or altered.
