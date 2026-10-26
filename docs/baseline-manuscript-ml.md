# Bounded four-model manuscript replay

Implementation prepared and reviewed 26 October 2026; XGBoost source review and
dependency preparation completed (see below); **not executed** at this checkpoint.
This branch implements the R route identified in
[the reconciliation](baseline-result-reconciliation.md), not the older Manu route.
No corrected feature selection, preprocessing/WGCNA rerun or historical-output
repair is part of it.

## Source and bridge contract

Runner: `scripts/baseline/manuscript-ml.R`. Helpers reuse the unchanged tested
`ml-support.R` plus branch-specific `manuscript-ml-support.R`. Existing ml.R,
its helper/planner, completed evidence and lock records are unchanged.

The recovered Machine_Learn notebook stays outside the repository. Its complete
SHA-256 is `24f7b02dd302afc48d695fdf7cb6b26968edd6b4b63212c28d33d2a3c6f6c1a1`.
The runner embeds **69→70→71→72→73→74** and export cells **8/13/20/28** verbatim,
including omitted arguments and positional probability indexing. It validates the
full notebook hash, 11 individual cell hashes (including 68), and exact text of
every executed source/export block before any split or fit. Source cell copies
are retained per run. It never reads the Zone.Identifier metadata.

Only cell 68's CSV bridge is replaced: read the same five hash-pinned inputs as
the existing ML runner, check upstream completed status and exact input schemas,
and assert metadata/sample identity/order without assigning row names by position.
A separate diagnostic records this assertion and the value mapping
Normal→Normal, ERpos→ER+, TNBC→TNBC, HER2pos→HER2+. Cell 70's as.factor produces
the source class order **ER+, HER2+, Normal, TNBC**, asserted rather than imposed.
Expression becomes a data frame with `optional=TRUE`, preserving raw gene names
and values. No make.names, sorting, imputation or extra scaling is introduced.
Feature names and bridge values are recorded/read back. The pinned panel protects
its 350-gene order and coverage.

The unused readr CSV-loader dependency is omitted with the bridge. Original
library order after that omission is dplyr, caret, randomForest, e1071, nnet,
xgboost, pROC, ggplot2. All attachment/default inspection occurs before the split
seed. Notebook evaluation is in .GlobalEnv; wrapper state stays in main().

## Analytical choices and RNG

- Cell 70 alone sets seed 2024 and calls createDataPartition(p=.7,list=FALSE).
  Expected historical split is 198/81 with training counts 30/115/19/34 and
  test counts 12/48/7/14 in the source class order. Record actual IDs and counts;
  checkpoint differences are reported, not repaired.
- RF: x/y interface, ntree=1000, importance=TRUE; SVM: radial, probability=TRUE;
  LR: direct multinom(y_train~., data=as.data.frame(X_train), trace=FALSE,
  MaxNWts=5000); XGB: multi:softprob, four classes, nrounds100, max_depth6,
  eta.1, verbose0, original matrix prediction reshape and max.col defaults.
- Preserve continuing RNG through RF→SVM→LR→XGB, with no SVM/LR seed resets.
  Default Mersenne-Twister/Inversion/Rejection is asserted. RNG snapshots are
  captured on both source return and source error; guards before each model and
  after validation prove wrapper work has not advanced R's RNG. Native SVM
  probability RNG repeatability remains unknown; no extra fit tests are added.
- Preparation/split failure stops every model. Otherwise all four independent
  branches are attempted even after another branch fails. The inherited branch
  helper separates training/source failure from validation/graphics failure.
  A continued branch after an earlier source error uses the actual consumed RNG
  state, which need not equal the complete historical sequence; no reset hides it.

## Faithful outputs versus diagnostics

Every run exclusively creates `Results/baseline_manuscript_ml/run-<UTC>-<PID>/`
and changes working directory there before source-derived writes. It cannot reuse
or overwrite earlier Manu/manuscript runs or original WGCNA results.

- `faithful/`: bridge/split RDS, raw model/prediction/probability/source-AUC evidence,
  12 source-named CSVs, measured model_summary.csv and model_comparison.png.
  Exports use existing predictions, never refit. CSVs/read-backs are checked.
  Model comparisons use the inherited environment-free comparison; non-model
  evidence remains strictly identical. This checks retained contents, not native
  pointer identity or later prediction equivalence after deserialization.
- `diagnostics/`: metadata/sample and feature-name records plus per-model
  probability dimensions, values, original row/column labels and alignment flags.
  Swapped or missing labels are reported without reordering/relabeling the source
  probability object or recalculating a corrected AUC. XGB's source reshape
  deliberately drops dimnames, so unlabelled row/column diagnostics are expected.
- `source_cells/`: exact recovered sources, including unexecuted cell 68.
- Root: stage/warning/message/error provenance, package paths/versions, function
  defaults/bindings, session, logs, final artifact manifest and audit-finalization
  JSON. Parent and new lock paths/hashes and API review are recorded.

The cells return only numeric AUCs, not their full ROC objects. Their settings
remain in verbatim source/formals and original pROC level/direction messages in
logs; the runner does not fabricate recovered historical ROC objects. Named
probability alignment is a diagnostic, never a silent correction. AUC CSV labels
reuse RF column order, as in the supplied export branch; factor order is the
explicit fallback if RF did not produce probabilities. This affects additional
exports only and is not a claim of historical RF success.

Historical accuracy/macro-F1, full confusion matrices and positional AUCs are
compared separately; discrepancies do not force model failure. Source-derived
scores can be internally consistent while class alignment requires review.
`diagnostic_status=review_required` is exposed separately in final JSON and does
not erase faithful outputs. Exit 0 means four branches and their evidence exports
completed; it is **not** an assertion of correct probability alignment, clinical
validity or historical equality. Exit3 means finalised mixed branch/preparation
failure; exit2 preflight blocked; exit1 wrapper/finalisation failure. Early
argument/path/tree errors may exit1 without a run directory.

Graphics close after every branch and again before final hashing. Logs close
before the manifest is written/re-read/re-hashed. review-finalization.json is an
atomic audit record excluded from its manifest, never COMPLETED. Finalisation
failure publishes no valid audit record. Abrupt process termination can prevent
finalisation. Parent messages are redirected to execution.log with flushed
labelled stdout copies; external stderr is not promised the original messages.

## Minimal additional dependencies and decision before installation

Read-only inspection found the prior Manu dependency bundle at
`/home/samuel/env-records/ml-dependencies-20261026T071424Z-77321/`:

- Existing ml-renv.lock has **149** records, SHA-256
  `4f7afa2d47ab3a43d0b1836887e842fc60f911b57d5a197bc16abbbc00b3ef85`.
  Keep it and the completed Manu run
  `Results/baseline_ml/run-20261026T073318Z-86649/` unchanged. That run's audit record
  reports RF/SVM succeeded and logistic training_failed, a finalised mixed outcome.
- Required RF4.7-1.2, caret7.0-1, pROC1.19.1, e1071.7-17 and nnet7.3-20
  are already represented in that extension/project environment. Current baseline
  Matrix1.7-4, data.table1.18.6.1 and jsonlite2.0.0 satisfy the saved candidate's
  declared import constraints; methods is a base R package. readr is not required
  by the replacement bridge; reshape2 is already in the extension but these
  selected metric exports do not need to load it.
- **XGBoost is absent.** Saved CRAN-PACKAGES.rds from 2026-10-26 07:14:43 UTC,
  origin https://cloud.r-project.org, hash
  `dbcb081168e3d794f5f5867235a136fc0bf6089f2dd38e52312d576554a566b0`,
  lists candidate **3.2.1.1**: R>=4.3.0; imports Matrix>=1.1-0,
  data.table>=1.9.6, jsonlite>=1.0 and methods; NeedsCompilation=yes.
  For that metadata candidate, the minimal additional R package is **xgboost
  alone**, with no baseline version replacement. This is a dated metadata finding,
  not verification of source availability, SystemRequirements or API compatibility.

**Selected XGBoost release (reviewed 26 October 2026): 1.7.11.1.** Cell 74 needs
the verbatim xgboost(data=...,label=...,objective=...) interface and a **flat
row-major multiclass probability vector** from predict(). Exact CRAN sources were
inspected in bundle
`/home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/`
(`xgboost-api-findings.txt`, `candidates.sha256`):

- **3.2.1.1 (current CRAN): incompatible.** xgboost(x, y, ...) replaces the
  interface; data/label/eta are only deprecated renames and params/callbacks are
  removed. Multiclass predict() returns an [nrows, ngroups] matrix, which the
  source matrix(...,byrow=TRUE) would scramble. Not used; no source adaptation.
- **1.6.0.1 (closest to the manuscript's coarse "xgboost1.6"): API-compatible but
  not buildable unmodified.** Ubuntu's R 4.5.2 compiles C++ with
  `-Werror=format-security`; src/xgboost_R.cc:44 calls `error(XGBGetLastError())`
  with a non-literal format, which GCC 15.2 rejects (`install-1.6.0.1-failed.log`).
  Building it would need a native compiler-flag override, left as a separate
  toolchain decision.
- **1.7.11.1: selected.** Source
  https://cloud.r-project.org/src/contrib/Archive/xgboost/xgboost_1.7.11.1.tar.gz,
  SHA-256 `c15b631be77ae17fef46166abffb3336738a812c219d82c601bc70664a88d7c5`.
  R/xgboost.R is byte-identical to 1.6.0.1's. predict() defaults to
  reshape=FALSE/strict_shape=FALSE and returns as.vector(ret) from libxgboost's
  row-major (n_row, n_groups) buffer, which matrix(...,ncol=K,byrow=TRUE) inverts.
  The only predict difference from 1.6.0.1 is the DMatrix-conversion thread count.
  It uses `Rf_error("%s", ...)` and builds with the unmodified toolchain. Its
  requirements (R>=3.3.0; Matrix>=1.1-0, methods, data.table>=1.9.6, jsonlite>=1.0)
  are met by retained records, so xgboost is the only addition
  (`xgboost-1.7.11.1-closure.csv`). The installed xgboost() body and predict
  defaults were checked against the reviewed source.

1.7.11.1 is a reproduction version, not a recovered historical build. Numerical
agreement with the historical 1.6-era fit is not assumed.

Extend the existing dependency preparation procedure in
[the Manu handoff](baseline-ml-implementation.md) using a new, separately named
manuscript bundle. Resolve the chosen XGBoost source's required closure against
**all 149 retained records**, not a fresh automatic upgrade plan. The existing
offline planner's root list does not include XGBoost; it must not be mistaken for
a resolved XGBoost plan. Review the selected DESCRIPTION/closure/source hashes,
then produce a **new** lock by retaining the existing 149 records and merging
only approved new snapshot records, as in that handoff's record-preserving merge.
The runner checks all 113 baseline records, every record from the explicit parent
Manu extension, R/repository/Bioconductor metadata, and expected DESCRIPTION
versions/resolved project-library paths. No lock/snapshot/bootstrap file is changed
by the runner or this task.

Prepared manuscript lock: `/home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/manuscript-renv.lock`
(150 records, SHA-256 `c5f429e188bdd0ea68f9ad76e8e01017a44e9ed150db38298c3ec3c940675cb6`).
It is the retained 149-record Manu extension plus the snapshot record for xgboost
1.7.11.1 only. A record-preserving merge verified that all 149 retained records
(including the 113 baseline records) and the R/Bioconductor metadata parse
identically. renv.lock, renv settings/bootstrap and the parent ml-renv.lock
(`4f7afa2d…`) were hash-checked unchanged. Standalone runs of the runner's
lock/library/API-review preflight checks passed against this lock.

The source review produced a separate JSON attestation at
`/home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/xgboost-api-review.json`
(SHA-256 `f38de57de52c05258fd7bb5b22ce280cae5118137cabf6b0bc3ae49437f3deba`). It
is not proof by itself of installed binary provenance. Required fields:

```json
{
  "version": "1.7.11.1",
  "source_sha256": "c15b631be77ae17fef46166abffb3336738a812c219d82c601bc70664a88d7c5",
  "assessment": "verbatim_api_compatible",
  "prediction_contract": "flat_row_major_multiclass_probability_vector",
  "reviewer": "Claude Code (claude-opus-5-5) static source review for Samuel, 2026-10-26; source https://cloud.r-project.org/src/contrib/Archive/xgboost/xgboost_1.7.11.1.tar.gz; evidence /home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/xgboost-api-findings.txt"
}
```

Version must equal the selected extension record; hash must be 64 hexadecimal
characters. The run records this file/hash and the selected package metadata.
Obtain actual tarball/build provenance independently; no fixture attestation can
substitute for that review.

## Resolved execution command

From the repository root with active project renv and a clean committed tree:

```sh
Rscript scripts/baseline/manuscript-ml.R \
  /home/samuel/wgcna-evidence-20261024/manuscript-reconciliation-inputs/Machine_Learn.ipynb \
  /home/samuel/wgcna-evidence-20261024/baseline-review/baseline \
  /home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/manuscript-renv.lock \
  /home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/xgboost-api-review.json \
  /home/samuel/env-records/ml-dependencies-20261026T071424Z-77321/ml-renv.lock
```

Do not point the new-lock argument at the unchanged 149-package parent: it lacks
XGBoost and must fail preflight.

## Checks and limitations

New checks: `python3 tests/static/check_manuscript_ml.py` and
`Rscript --vanilla tests/runtime/check_manuscript_ml.R`. The static checker pins
the full recovered notebook/11 selected cells, ten verbatim source/export blocks,
sole source seed, isolated outputs and finalisation order, and compares preserved
Manu infrastructure/lock/bootstrap bytes to HEAD. Runtime fixtures use tiny
synthetic categories/probabilities/predictions/CSV tables and random draws only:
bridge order/raw names, positional-vs-labelled diagnostics, uninterrupted RNG,
actual evaluator's error-path RNG capture, measured metrics, export read-backs
and version/API review guards. No model cell or main() is executed.

Existing Manu static/runtime checks are rerun as regressions without changing
that implementation. R scripts are parsed; tracked/staged/new-file whitespace
is checked. Actual RF/SVM/LR/XGB fitting, probability layouts on the installed
build and end-to-end finalisation are not exercised by these checks.
Full-cohort supervised panel/preprocessing leakage, repeated patients, confounding,
ROC direction selection and unknown historical sessions remain baseline limits.

Checks actually run for this implementation: both new check commands passed
(seven new runtime fixture groups); the original static checker and all seven
Manu runtime fixture groups passed; all three new R files parsed. Existing Manu
review-finalization manifest hash and all 31 artifact hashes/byte counts were
verified read-only. Protected implementation/lock/bootstrap files match HEAD.
Whitespace checks cover tracked/staged changes and every new deliverable.
These code checks fitted no model. Dependency preparation (xgboost 1.7.11.1 only,
separate manuscript lock) was performed separately in the bundle above; the
manuscript checks and Manu regressions passed again afterwards.

## Execution record (26 October 2026)

Executed once from a clean tree at commit
`40926994f7e45aa2eb8dce8657a490f51d1316c3` on `analysis/initial-review`, with the
resolved command above. No tuning, retry or analytical-cell change.

- Run directory: `Results/baseline_manuscript_ml/run-20261026T113840Z-17527/`.
- Exit code 0; `workflow_status = finished_all_models_succeeded`;
  `diagnostic_status = review_required`; no failed stages or warnings.
- Console, `/usr/bin/time -v` output, exit code and commit:
  `/home/samuel/env-records/manuscript-ml-dependencies-20261026T105445Z-4475/execution-logs/`
  (10.19 s wall clock; 558,412 kB maximum resident set size).

| Model | Accuracy | Macro F1 | Confusion vs ML 71–74 / 120 | Positional AUC (ER+, HER2+, Normal, TNBC) |
| --- | ---: | ---: | --- | --- |
| RF | .9876543 | .9805097 | match / match | .9903382, 1, 1, .9978678 |
| SVM | .9876543 | .9805097 | match / match | .7971014, .9753788, .7413127, .7910448 |
| LR | .9629630 | .9248918 | match / match | .9263285, 1, .9980695, .9861407 |
| XGB | .9753086 | .9698322 | match / match | .9794686, 1, 1, .9904051 |

Positional AUCs agree with saved ML 120 for all four models and with ML 73/74,
but disagree with ML 71 (RF ER+) and ML 72 (all SVM classes). The runner's
built-in AUC checkpoint used ML 71–74, so its final JSON reports RF/SVM
`positional_source_auc = differs_from_checkpoint`. Per-cell attribution is in
the [reconciliation](baseline-result-reconciliation.md#separate-historical-branches-and-numerical-checkpoints);
neither saved set is preferred and no cause is asserted.

Class-alignment diagnostics (separate from the faithful AUCs; nothing relabelled):
RF and LR probability columns are aligned; SVM columns are **Normal, ER+, TNBC,
HER2+**, so its positional AUCs pair classes with the wrong columns; XGB columns
are unlabelled by the source reshape. All four probability matrices are 81×4,
finite and row-normalised.

Integrity: the 42-entry `artifact_checksums.csv` (SHA-256
`f145768b36ad16fba24fd893fcffe2a4612c5ffb2ea0470ae2dd4ada03ad2e7c`) was
independently re-verified for exact file set, byte counts and hashes, and matches
`review-finalization.json`. The Manu run, Manu lock and manuscript lock were
unchanged by hash afterwards.

Limitations: pinned full-precision RDS inputs replace the historical
`/content/*.csv` files; package versions are reproduction locks (xgboost 1.7.11.1,
not the coarse historical 1.6); metric agreement does not establish historical
sample membership, sessions or fitted-model identity; the SVM column mismatch is a
reproduced source defect, not corrected here; leakage, repeated-patient and
study/category confounding limits remain. This is not independent validation.
