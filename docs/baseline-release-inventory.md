# Baseline release evidence inventory and acceptance assessment

RC1 preparation record, 26 October 2026, at repository HEAD
`40926994f7e45aa2eb8dce8657a490f51d1316c3` on `analysis/initial-review`. Working-tree candidate; not committed, pushed or tagged.
The frozen payload inventory and verification outcome are recorded separately
under release/baseline-rc1/. No preprocessing, WGCNA or model step was
rerun to prepare it.

The complete per-file SHA-256 list (207 files, `sha256sum` format) is
[baseline-release-inventory.sha256](baseline-release-inventory.sha256). It covers
both ML runs, the preprocessing run, both dependency bundles (extracted XGBoost
source trees omitted; their tarballs are listed), the WGCNA evidence, the
reconciliation inputs and the original Manu notebook. The tables below repeat
the anchor hashes.

## Repository implementation commits

| Stage | Commit | Code |
| --- | --- | --- |
| Preprocessing | `eab95f9` (record `a5f99a1`) | `scripts/baseline/preprocess.R` |
| WGCNA | `8553d820db26c03f942166864aa3ae198548a804` | `scripts/baseline/wgcna.R` |
| Manu three-model ML | `db8fb67a089842d3c07359dfd24ca2dee1ad2ae7` | `scripts/baseline/ml.R`, `ml-support.R`, `ml-dependency-plan.R` |
| Manuscript four-model ML | `40926994f7e45aa2eb8dce8657a490f51d1316c3` | `scripts/baseline/manuscript-ml.R`, `manuscript-ml-support.R` |

`renv.lock` (113 records, SHA-256
`c753d978b68fad0c56f146656714c56186980fba4aa6ea64a5e0f915be0c1782`) is unchanged
since the WGCNA lock commit `9e89668`.

## Runs

| Run | Path | Commit | Outcome | Manifest SHA-256 | Audit record SHA-256 |
| --- | --- | --- | --- | --- | --- |
| Preprocessing | `Results/baseline_preprocessing/run-20261013T053229Z-205981/` | `eab95f9` | completed (exit 0) | no manifest (14 files hashed in inventory); provenance `10bae632b4abd190…` | — |
| WGCNA (VM) | `run-20261024T120729Z-46759` inside archive below | `8553d82` | **incomplete**: all analytical stages finished, output validation failed (missing heatmap), exit 1 | 27 verified entries (archive) | `verification.json` `d777fdde5eda7d4d…` |
| Manu ML (M1) | `Results/baseline_ml/run-20261026T073318Z-86649/` | `db8fb67` | exit 3, `finished_with_model_failure` (RF/SVM succeeded, caret LR training failed) | `1b50e012044a64402a74f323412627461eb05e085dc97bc7a8d0c2cd60c40163` | `c32bfe9656758125…` |
| Manuscript ML (R1) | `Results/baseline_manuscript_ml/run-20261026T113840Z-17527/` | `4092699` | exit 0, `finished_all_models_succeeded`, `diagnostic_status = review_required` | `f145768b36ad16fba24fd893fcffe2a4612c5ffb2ea0470ae2dd4ada03ad2e7c` | `8960c2f4f3f2a4f9…` |

Full 64-character values for abbreviated hashes are in the `.sha256` file.

## Evidence outside the repository

| Item | Path | SHA-256 |
| --- | --- | --- |
| WGCNA run archive | `/home/samuel/wgcna-evidence-20261024/wgcna-20261024T171133Z-54144.tar.gz` | `f1bb9b76a5316dffbed5a80bf5449185280ca7a5d3035336c2ea46a922de92a9` (re-checked against its sidecar) |
| WGCNA review copy, audit, recovery | `/home/samuel/wgcna-evidence-20261024/baseline-review/` | per file in `.sha256` |
| Verified 350-gene panel | `…/baseline-review/baseline/final_hub_genes.csv`, `final_hub_genes_info.csv` | `68ab1b6052ecbf3b…`, `4255abb160a36176…` |
| Machine_Learn notebook | `/home/samuel/wgcna-evidence-20261024/manuscript-reconciliation-inputs/Machine_Learn.ipynb` | `24f7b02dd302afc48d695fdf7cb6b26968edd6b4b63212c28d33d2a3c6f6c1a1` |
| Manuscript PDF | `…/manuscript-reconciliation-inputs/Adegbola_et_al2.pdf` | `0963ede3e17f51e560489d09aaf40a425ee422e1b80c3a11f171325cb26abafd` |
| Manu ML dependency bundle | `/home/samuel/env-records/ml-dependencies-20261026T071424Z-77321/` | per file in `.sha256` |
| Manu ML lock (149 records) | `…/ml-dependencies-20261026T071424Z-77321/ml-renv.lock` | `4f7afa2d47ab3a43d0b1836887e842fc60f911b57d5a197bc16abbbc00b3ef85` |
| CRAN metadata snapshot | `…/ml-dependencies-20261026T071424Z-77321/CRAN-PACKAGES.rds` | `dbcb081168e3d794f5f5867235a136fc0bf6089f2dd38e52312d576554a566b0` |
| Manu source tarballs (36) | `…/ml-dependencies-20261026T071424Z-77321/src/`, `source-tarballs.sha256` | per file in `.sha256` |
| Manuscript dependency bundle | `/home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/` | per file in `.sha256` |
| Manuscript lock (150 records) | `…/manuscript-ml-dependencies-20261026T105445Z-4475/manuscript-renv.lock` | `c5f429e188bdd0ea68f9ad76e8e01017a44e9ed150db38298c3ec3c940675cb6` |
| XGBoost API review record | `…/xgboost-api-review.json` | `f38de57de52c05258fd7bb5b22ce280cae5118137cabf6b0bc3ae49437f3deba` |
| XGBoost API findings | `…/xgboost-api-findings.txt` | `981bf91a3530f90c…` |
| XGBoost candidate tarballs | `…/candidates/{3.2.1.1,1.6.0.1,1.7.11.1}/tarball/`, `candidates.sha256` | 1.7.11.1 `c15b631be77ae17fef46166abffb3336738a812c219d82c601bc70664a88d7c5` |
| Failed 1.6.0.1 build log | `…/install-1.6.0.1-failed.log` | `44bbe48cb67e02cf…` |
| R1 console/timing/exit logs | `…/manuscript-ml-dependencies-20261026T105445Z-4475/execution-logs/` | console `2b376da3594d817f…`, time `a9578004ff47c348…` |
| M1 console/timing logs | **not preserved**; see `…/ml-dependencies-20261026T071424Z-77321/execution-logs/NOTE.txt` | NOTE `8093d10987e5012e…` |

M1's external console and `/usr/bin/time` logs were written only to a temporary
session scratchpad and were cleared before being copied. They are not
reconstructed. In-run `execution.log`, `execution_provenance.rds` (process time,
`/proc/self/status`) and `review-finalization.json` survive under M1's manifest.

## Narrowed one-command release acceptance

The accepted entry point is now frozen-evidence verification, not a rebuild:

```sh
python3 scripts/release/verify_frozen_evidence.py Results/baseline_release/rc1
```

See [RC1](baseline-release-candidate.md) for the portable layout, authority,
classifications, patient audit and archival requirements. The legacy 207-file
checksum list above remains a source preservation record with original paths;
release/baseline-rc1/evidence-manifest.json is the portable trusted index.
release/baseline-rc1/verification-result.json records the actual local outcome.
A clean clone cannot automatically chain the four existing runners; that fact
is documented separately in [stage replay](baseline-stage-replay.md) and is not
claimed or required by the narrowed acceptance.

Exact 149/150-package ML locks, XGBoost review/findings/build references and the
patient audit are now in version-controlled release locations. External source
inputs, build archives/logs and monitoring/retrieval tooling are included in the
portable local preservation layout, without inventing a public download URL.
M1 external logs remain lost, with surviving in-run evidence accepted as directed.
Historical AUC conflicts, the SVM source defect, incomplete WGCNA and unsupported
claims have explicit accepted **baseline** dispositions in the RC document.

## Patient-overlap audit

M1 has 28 known patients shared across train/test (28 samples on either side);
R1 has 31 (31 samples on either side). Both have 121 samples without reported
patient identity: 88 training, 33 test. Exact groups/sample IDs and input hashes
are in release/baseline-rc1/patient-audit/. No inference of independence is made.

## Remaining release requirements

- Done: independent Claude review of the candidate, frozen verifier and
  dispositions (no release blockers).
- Recommended, not required for this scoped release: a durable archival
  custodian/retention destination and a second independently verified copy after
  authorised transfer. Current custody is one verified local bundle; no off-host
  copy is established (see the RC document's preservation policy).
- Separate authority for push or tag. No clean-clone rebuild or corrected
  scientific validation is certified by this evidence release.

### Documented historical/scientific limitations (not release blockers by themselves)

- Historical package versions and sessions are unrecovered; locks record
  reproduction versions (including xgboost 1.7.11.1 versus the manuscript's 1.6).
- Historical ML inputs were `/content/*.csv` files; replays use pinned
  full-precision RDS. Historical split membership and fitted-model bytes are unknown.
- Full-cohort label-informed panel selection and preprocessing, random split
  without patient/study grouping, repeated patients, study–label confounding and
  Normal being a tissue category: no ML result is independent validation.
- Manu caret LR fails by construction (nnet weight limit); the manuscript's LR
  result comes only from the separate direct-multinom branch.
- Gene-annotation provenance and the parked 156-versus-158 question remain open.
- Untested second-run and other-machine reproducibility.
