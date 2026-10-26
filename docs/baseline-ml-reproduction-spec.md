# Original ML reproduction specification

Date: 25 October 2026 (Africa/Lagos). Status: revised after Claude source and implementation reviews; bounded implementation prepared for review, not executed. No package installation or model training has been performed in preparing these revisions.

## 1. Purpose and scope

Reproduce, or document the inability to reproduce, the original Manu notebook's ML branch using the preserved baseline inputs and 350-gene panel. Retain its historical analytical choices and defects. This task establishes traceability and execution evidence; it does not validate biomarkers or independent predictive performance.

Existing Notion task: [Reproduce original ML workflow](https://app.notion.com/p/3f0316a094da819eaa4bd05092937116). Acceptance: original outputs reproduced or failure documented; leakage audit recorded. The task remains In progress. WGCNA review closure does not establish ML completion or completion of the wider original-analysis milestone.

Exclude network/TOM reconstruction, preprocessing reruns, kME repair, corrected feature selection, model optimisation, nested evaluation, extra classifiers, cloud operations and manuscript claims. Do not investigate the parked 156-versus-158 question.

## 2. Evidence and limits

- Authoritative source: `notebooks/original/Original_Manu_Pipe.ipynb`, supplied in baseline-source-review.tar.gz. Notebook SHA-256: `ca9671af2eb21bf551641d1e01bfebef5926c1547fee60c86e6bc06caff2f45c`.
- Reviewed WGCNA implementation: commit `8553d820db26c03f942166864aa3ae198548a804`. Original WGCNA attempt remains failed/incomplete; recovered heatmap is separate.
- Verified local archive: `wgcna-20261024T171133Z-54144.tar.gz`, SHA-256 `f1bb9b76a5316dffbed5a80bf5449185280ca7a5d3035336c2ea46a922de92a9`.
- Samuel's local check matched both saved final-panel CSVs to the exact seven manual top-50 kWithin selections and order. The 350 genes and masterNodes IDs were unique, with no selection-boundary ties at saved CSV precision. Connectivity itself was not independently recomputed.
- Notebook cells contain saved text outputs but all selected execution counts are null. Their presence does not prove a continuous execution sequence, package environment, sample split identity or fitted-model identity.
- A user-run search found none of five exact filenames outside `.git` and `renv` in the local project: RF/SVM/logistic RData files, `ml_input_hub_panel.csv`, and `WGCNA_ML_inputs.RData`. This is a scoped absence finding, not proof that no copies exist elsewhere. Do not expand the search without a task-relevant reason.
- Expression and model bytes are not attached here. Local input availability and performance reproducibility remain to be checked; neither may be assumed from this specification.

## 3. Selected source branch

All cell numbers below are one-based notebook cell positions, including non-code cells.

| Cell | Role | Treatment |
|---|---|---|
| 48, 52 | Save bridge objects after WGCNA | Evidence of intended object names only; bridge from verified saved files rather than rerunning WGCNA |
| 55 | Build ML matrix from final_hub_genes; make.names; attach labels | Include analytical statements unchanged |
| 56 | Installation, package loads and split | Do not execute installation; redundant split branch omitted in favour of 57 |
| 57 | Load randomForest/caret/pROC; seed 2024; stratified split | Include; authoritative split for this selected branch |
| 58 | RF with 1,000 trees, predictions, AUCs, figures and save | Include unchanged analytical choices |
| 59 | Radial SVM with probability estimates and seed 2024 | Include except installation statement |
| 60 | caret multinomial logistic regression with seed 2024 | Include except installation statement; preserve failure rather than repair |
| 133–135 | Installation/environment history; 134–135 have empty source with saved installation outputs | Exclude from execution; retain as historical environment evidence |
| 136 | Duplicate of cell 56 | Archive as alternate history; exclude from selected execution |
| 137–139 | Alternate RF using object model and omitted tree count; errors in 137–138, no saved output in 139 | Document separately; exclude from selected execution |

Selected analytical sequence: **55 → 57 → 58 → 59 → 60**. This is a proposed explicit reconstruction from the stored source, not a recovered historical execution order. Independent review must verify the extraction and appropriateness of this branch before implementation.

Preserve source text and hashes of included/excluded cells. Exclude installation calls, not analytical arguments. Record any wrapper adaptations; do not silently repair gene names, defaults, selection, model errors or ROC direction.

## 4. Input bridge and invariants

Use saved baseline preprocessing expression/metadata and the verified WGCNA panel; never reconstruct them from raw counts for this task.

| Input | Required identity |
|---|---|
| expression_samples_by_genes.rds | SHA-256 `c5d30758d2fdad1bbb980845958e61370c7a67592130f6e41b4ec0837449b3b4` |
| aligned_metadata.rds | SHA-256 `c6b766098f7d4dea34e60fa7b7167994f4845d983f5a57366547713a77a04644` |
| preprocessing execution_provenance.rds | SHA-256 `10bae632b4abd190267bd960640d265ece960b5616841aca65de213ced20f9c7` |
| final_hub_genes.csv | Archive member `outputs/run-20261024T120729Z-46759/final_hub_genes.csv`; 3,034 bytes; SHA-256 `68ab1b6052ecbf3b9882eb66d7046aea3bab0ae3501fdae32bb647c4738b2335` |
| final_hub_genes_info.csv | Archive member `outputs/run-20261024T120729Z-46759/final_hub_genes_info.csv`; 9,603 bytes; SHA-256 `4255abb160a36176b128dc9d46f5679e98e83c86300441365e739ab3711911be` |

Panel trust chain: independently recorded archive hash → archived original manifest and member hashes → explicitly pinned CSV bytes above. The source run is failed/incomplete and has no COMPLETED marker; its manifest is not certified by such a marker. The CSV hashes were checked against both the supplied review files and Claude's local manifest check. Read gene identifiers as character strings (for example, `colClasses = "character"` for panel CSVs); preserve numeric-looking IDs without conversion.

Known preprocessing directory: `Results/baseline_preprocessing/run-20261013T053229Z-205981/`. Treat paths as candidate locations; verify actual files, hashes and schemas. Use safe selective archive reading for panel files if necessary. Do not extract or load TOM/adjacency. Check RDS objects in isolated environments where applicable; load RData only into explicit isolated environments.

Required bridge assertions:

1. Expression is numeric, 279 samples × 25,750 genes, with unique nonmissing sample/gene IDs. Metadata row names match expression row names exactly in order; there is no separate sample-ID column. Fail on mismatch; do not repair by sorting or dropping rows.
2. Subtype levels/order are Normal, ERpos, TNBC, HER2pos, with counts 26, 42, 48, 163. Retain batch metadata for provenance, but do not add batch as a predictor.
3. Panel contains exactly 350 unique gene IDs in the verified saved order; all occur in expression. Cell 55 uses `intersect(final_hub_genes, colnames(expr))`. A missing gene is a bridge discrepancy: stop before training, even though the notebook merely warns. This is an explicit wrapper safeguard, not an altered successful analytical path.
4. Preserve `make.names(colnames(ml_matrix))` as written, including omitted arguments. Save original-to-transformed name mapping and check for collisions and reserved response-name conflicts. If ambiguous names occur, stop and report; do not use make.unique or silently rename again. Record this as an execution constraint requiring an explicit decision.
5. Feature matrix is 279 × 350, finite and in the saved panel/sample order. No new scaling, imputation, filtering, feature selection or batch correction is added by the wrapper. Preserve algorithm-internal defaults such as SVM scaling; record their effective values.
6. Verify read-back identities of saved bridge objects; retain hashes and source relationships. Do not treat newly exported files as historical originals.

## 5. Environment and RNG

Uploaded lock: R 4.5.2; renv 1.3.1; nnet 7.3-20. Four direct ML dependencies are absent: randomForest, caret, pROC, e1071. This says nothing about whether they happen to be installed locally.

The notebook has an alternate-branch message showing randomForest 4.7-1.2. Record this as historical evidence, not a complete recovered environment or proof that the primary RF used that version. Historical caret, pROC, e1071, RNG settings and complete session state are unknown. Cells 59–60 show e1071 and nnet installation into the historical site library; historical nnet must not be equated with the currently locked 7.3-20. Claude also confirmed the four missing direct dependencies are absent from the local library. caret brings a substantial transitive dependency set; inspect and report its actual resolved additions rather than assuming only four packages will change.

After specification review, Codex must first inspect local packages, library paths, repository instructions and lock configuration without installation. Propose exact package additions and transitive dependencies compatible with R 4.5.2 and the retained environment. Preserve existing lock records; report any required changes to them before mutation. Newly selected package versions are reproduction versions, not recovered historical versions. No automatic install or broad renv snapshot belongs in a training script.

Execution must use a fresh process with a verified locked environment and no restored workspace or ad hoc attached packages. Record package DESCRIPTION versions/paths, lock hash, sessionInfo, R build, RNGkind, thread/parallel configuration, and relevant function defaults/methods. Registering a new parallel backend is outside scope. Historical broad-session package masking is unknown; record the selected reconstruction's bindings.

RNG sequence is part of the method:

- Cell 57 calls set.seed(2024), then createDataPartition with p=0.7 and list=FALSE. Record actual row indices, sample IDs, order, factor levels and .Random.seed after splitting.
- **Cell 58 has no new seed.** Continue from the split RNG state into RF. Do not reset seed 2024 before RF or execute additional random diagnostics first. Record RNG state before/after the stage without consuming random numbers.
- Cell 59 resets seed 2024 immediately before SVM training, as in the source. Do not claim that this controls every internal libsvm probability-estimation RNG: inspect the exact selected e1071/libsvm source when assessing repeatability and record its RNG mechanism if established. An unresolved native probability RNG is a documented limit, not a blocker to one faithful execution. Prediction/probability reproducibility may differ. Any repeated-fit diagnostic must be a separate authorised experiment, not an extra fit inside the primary RNG sequence.
- Cell 60 resets seed 2024 immediately before caret training, as in the source. Preserve omitted trainControl/tuneGrid/tuneLength settings; capture the resolved resampling/tuning setup and effective defaults where possible.
- Logs, identifiers, temporary paths and provenance capture must not consume the analytical RNG stream. Do not run stages in separate fresh sessions without restoring the exact required RNG and model state. Assert RNGkind() is Mersenne-Twister / Inversion / Rejection and assert exact equality of the post-split RNG state and the state immediately before RF; do not reset it to force equality.

## 6. Historical checkpoints

These are stored notebook observations, not targets to force or proof of independent performance.

| Checkpoint | Historical observation | Required comparison |
|---|---|---|
| Feature matrix, cell 55 | 279 × 350; first genes UGT8, ROPN1, VGLL1, GABRP, ROPN1B | Exact dimensions/ordered IDs where available |
| Split, cell 57 | 198 training, 81 test | Counts; exact historical sample IDs unavailable |
| Training counts | Normal 19, ERpos 30, TNBC 34, HER2pos 115 | Exact category counts |
| Test counts | Normal 7, ERpos 12, TNBC 14, HER2pos 48 | Exact category counts |
| RF, cell 58 | Printed accuracy 0.975; 79/81 correct | Compare full confusion matrix and derived 79/81, not merely rounded text |
| SVM, cell 59 | Printed accuracy 0.988; 80/81 correct | Compare full confusion matrix and derived 80/81 |
| RF and SVM ROC | All four AUCs printed as 1 | Historical probabilities/unrounded AUCs unavailable; displayed 1 is not proof of exact AUC 1 |
| Logistic, cell 60 | Missing resampled-performance warning, then Error: Stopping | Record actual outcome; historical root cause unknown |
| Alternate RF, cell 137 | Object '101929498' not found | Historical alternate-path error only |
| Alternate prediction, cell 138 | Object model not found | Consequent recorded error; no successful model implied |

Alternate-session clue: error identifier `101929498` is in the verified panel and becomes `X101929498` under cell 55. This is consistent with a different feature-name/session state in that alternate branch, but does not establish the exact prior execution sequence. Claude reports six transformed feature names, no collisions and no Subtype conflict in the verified local bridge.

Historical confusion matrices use prediction rows and reference columns, ordered Normal, ERpos, TNBC, HER2pos:

| Model | Predicted class | Normal | ERpos | TNBC | HER2pos |
|---|---|---:|---:|---:|---:|
| RF | Normal | 7 | 0 | 1 | 0 |
| RF | ERpos | 0 | 12 | 1 | 0 |
| RF | TNBC | 0 | 0 | 12 | 0 |
| RF | HER2pos | 0 | 0 | 0 | 48 |
| SVM | Normal | 7 | 0 | 0 | 0 |
| SVM | ERpos | 0 | 12 | 1 | 0 |
| SVM | TNBC | 0 | 0 | 13 | 0 |
| SVM | HER2pos | 0 | 0 | 0 | 48 |

Model settings to preserve:

- RF: formula Subtype ~ ., data=train, importance=TRUE, ntree=1000; other arguments omitted. Save their effective defaults and resolved method. Do not substitute alternate-branch default tree count.
- SVM: x/y interface, radial kernel, probability=TRUE; seed 2024; preserve omitted scaling/cost/gamma and other arguments. Probabilities are matched by class names, as the executable source does, rather than relying on its positional comment.
- Logistic: caret::train via the source's resolved train function, method="multinom", trace=FALSE; seed 2024. Preserve omitted tuning, resampling and nnet limits. Do not increase MaxNWts or repair fitting to obtain a result. Any such change is a separate corrected experiment.
- ROC: retain pROC::roc calls on binary one-versus-rest labels with source-omitted levels/direction. Record resolved levels/direction, messages and unrounded AUCs. Automatic direction selected using test outcomes remains a methodological limitation; do not silently change it in faithful reproduction.

Matching class counts alone does not establish matching sample IDs. Matching performance does not prove a recovered historical RNG/session state.

## 7. Wrapper, provenance and output contract

Implement only after independent specification review. Work in a new ignored local run directory, never the original WGCNA run. The input archive, original results, notebooks and preprocessing outputs are read-only. Repository additions follow local AGENTS.md and require separate implementation review; the runner remains unexecuted.

Preserve the selected cells' analytical sequence in one process. Installation statements are excluded. Evaluate notebook cells in .GlobalEnv as in the notebook; keep wrapper state local so formula environments do not capture it in saved models. Capture stage starts/ends, warnings, messages, errors and calls. A cell-55 preparation or cell-57 split failure stops analysis and leaves all model branches not reached. Once preparation and split pass, attempt each independent model branch 58, 59 and 60 in order, even if another branch fails training or evidence validation. Cells 59 and 60 retain their own source seed resets; never add a seed before RF. Close branch graphics after success or failure and retain the original error and any cleanup error. Do not fabricate outputs for failed branches. This explicitly authorised policy supersedes the prior first-model-failure stopping rule.

Do not change function lookup or introduce wrapper bindings that alter the source's function resolution. Record resolved function provenance where masking matters. Source validation must compare extracted analytical blocks with notebook JSON.

Minimum retained evidence:

- Input/source/lock/script hashes, notebook cell identities, package/session/RNG records and bridge assertions.
- Ordered original/transformed feature IDs and ordered sample IDs; training/test indices, category counts and input matrix used.
- Stage logs and status: successful, failed, not reached or preflight blocked. A known historical failure is not automatically a successful new execution.
- For each completed model: fitted object, named predictions and probabilities keyed by sample ID, true labels, confusion matrix, unrounded metrics, ROC settings, and recorded effective parameters. Validate probability class names, dimensions and finite values; document deviations without silently repairing predictions.
- Source-requested `ml_input_hub_panel.csv` from cell 55, RF figures/model saves and SVM/logistic saves when those stages reach them. Extra prediction/provenance exports are wrapper additions, clearly labelled. Persist model/prediction evidence promptly on successful stages so a later failure does not discard it.
- For completed caret fits, retain tuning/resampling information and split membership where available. For failed fits, retain warnings/errors and whatever settings were established; do not claim unavailable resampling indices were recovered.
- Stage-aware artifact manifest with SHA-256 and byte counts, sessionInfo, and a concise comparison report. Finalize graphics/logs before hashing. Failure records must not claim overall completion; no original completion marker is created or changed.
- Isolated read-back checks for saved objects and CSV IDs/order/numbers. Recompute metrics from saved predictions/probabilities to check internal consistency. Separate these checks from historical comparisons.

Resource expectation: no gene-by-gene matrix is needed. The ML feature matrix has 97,650 numeric entries; a double payload is about 0.75 MiB, excluding metadata/objects. Full saved expression is larger but is not a TOM. RF/SVM/caret memory/runtime remain unmeasured; do not guarantee local feasibility or a duration. Capture elapsed time and process memory where available without introducing unnecessary monitoring infrastructure.

### Mixed outcomes and wrapper finalisation

A completed audit workflow is distinct from all models fitting successfully. The likely-but-unproven mixed case is RF and SVM succeeding, followed by a cell-60 training failure. Record model status separately from wrapper status and historical agreement:

| Field | Allowed values / meaning |
|---|---|
| workflow_status | preflight_blocked, wrapper_failed, finished_with_preparation_failure, finished_all_models_succeeded, finished_with_model_failure |
| model status | succeeded, training_failed, validation_failed, not_reached; branch records separately report training and validation status |
| historical comparison | matches_available_checkpoint, differs_from_checkpoint, not_verifiable |
| failure comparison | same_stage_and_observed_signature, different_failure, not_verifiable; a shared generic Error: Stopping alone does not establish a common cause |

If RF/SVM complete and pass saved-prediction/metric checks, but logistic fails with intact diagnostics, set workflow_status=finished_with_model_failure. Preserve successful models and their independent historical-comparison results. This is an auditable mixed outcome, not an all-model success or a wrapper failure. Do not increase fitting limits to change its classification.

Write `review-finalization.json` only after logs, stage outputs, failure evidence and manifest are finalised and the manifest is independently verified. It records workflow/model statuses, historical comparisons, manifest hash and all failed stages. It is an audit-finalisation record, explicitly **not** an analysis-success marker. Do not write COMPLETED. If wrapper finalisation/integrity fails, no valid review-finalization record may be published. Write it atomically and retain any failure diagnostics.

Proposed process exit convention: 0 for internally verified all-model execution; 3 for a fully finalised execution with a preparation failure, model training failure or model evidence-validation failure; 2 for preflight blocked; 1 for wrapper/integrity/finalisation failure. Record historical agreement independently: matching or differing historical metrics must not be conflated with these exit codes. A historical discrepancy still needs explicit review before task closure.

Capture caret's per-resample fitting warnings/errors, tuning parameters, resample identifiers when exposed, and original diagnostic text. A plausible weight-limit explanation is that four-class multinomial fitting with 350 predictors can exceed the default 1,000-weight limit (the reviewer estimates 1,404 weights). This is a hypothesis, not the established historical cause. Inspect the selected nnet/caret source and actual fit diagnostics to establish the applicable weight count and limit. Do not run an extra model, alter MaxNWts, or replace caret solely to confirm it. If inner diagnostics are unavailable or only the generic stopping error is retained, classify the cause as not_verifiable. Require manual assessment of the actual recorded failure before calling its signature consistent with history. The runner leaves failure_comparison not_verifiable for that review; it does not automatically equate generic stopping messages.

## 8. Leakage and scientific limits

1. The panel is selected using all samples and subtype associations before the split. Test labels therefore influence supervised feature selection.
2. Preprocessing was fitted on the full cohort and preserved subtype/category effects. It is not a training-only prediction pipeline.
3. The split is category-stratified, not patient- or study-grouped. Known repeated patients exist in GSE243375; actual cross-split overlap must be assessed from sample/patient IDs if available, not presumed from a seed. Independence elsewhere remains unresolved.
4. Severe study/category imbalance, a dominant HER2pos category and limited cross-study overlap constrain generalisation. Random splitting does not establish transport to a new study.
5. Normal is a tissue category, not a cancer subtype; receptor categories are not intrinsic molecular subtype assignments.
6. Printed perfect AUCs and high accuracies from this branch cannot establish unbiased prediction, clinical usefulness or biomarker validity.

The corrected analysis must separately define independent units, defensible comparisons, study-aware validation and training-only selection/transforms, or narrow the question if these data cannot support such evaluation. Do not implement corrections inside historical reproduction.

## 9. Acceptance and stopping rules

Specification acceptance:

- Claude independently checks source-cell selection, historical output transcription, seed sequence, omitted defaults, input bridge, missing dependencies and limits. Blockers must be resolved before implementation or installation.
- Exact historical package/session recovery is explicitly unavailable. The comparison policy must allow honest discrepancies rather than forced agreement.

Execution readiness, assessed later:

- All required local input bytes and identities verified; 350-gene/sample bridge passes.
- Reproduction dependency plan reviewed; exact versions locked and environment verified without silently replacing existing baseline records.
- Implementation/source-fidelity and provenance checks reviewed; fresh-process local execution and its scope agreed.

Execution review outcomes:

- Internally verified all-model execution or mixed outcome: apply the explicit workflow/model statuses and exit rules in section 7. Input/seed/environment/output traceability and completed-model read-back/metric checks must pass. Separately classify historical agreement as matching at available precision, discrepant, or not verifiable.
- Documented failure: retain every failed branch and diagnostics, distinguish training from validation failure, and attempt the remaining independent model branches. Preparation/split failure alone prevents all model attempts. A specific failure does not certify any unexecuted or unvalidated outputs.
- Preflight blocked: record the missing input/dependency and stop; this is not an attempted model fit or evidence of the historical failure's cause.
- The Notion task closes only after its recorded acceptance is met with reviewable outputs or documented actual failure plus the leakage audit. Draft specification and scoped missing-file inventory alone do not close it. The wider release/manuscript-number ledger remains separate.

## 10. Immediate handoff

**Claude Code — review only:** Read this specification, applicable AGENTS.md, the original notebook, existing baseline docs and renv.lock. Verify cell numbers/hashes, recorded output tables, branch choice, RF RNG continuation, SVM/caret defaults, input schema/hashes and scientific boundaries. Report blockers by section and source cell; do not edit, install, train, repair or run the notebook. State whether it is ready for bounded implementation/dependency planning, not whether results are validated.

**Codex — after review:** Resolve specification blockers first. Then inspect local input availability and package state, propose a minimal dependency plan, and implement the source-faithful runner/provenance checks in the existing project under its repository rules. Do not install, train, commit, push, tag, touch original evidence or update Notion as part of that initial implementation handoff. Return the exact changed files, validation and next execution command for review.

**Samuel:** Supply the Claude review. After blockers and implementation review are resolved, run the single agreed local command and return its report. No VM restart or WGCNA/TOM rerun is part of this route.

**ChatGPT:** Reconcile evidence, scope and Notion status; distinguish historical observations, fresh reproduction and scientific validation throughout.

## Appendix: source-cell SHA-256

Hash is SHA-256 of the UTF-8 concatenation of each cell's source strings as read from notebook JSON; no newline normalisation.

| Cell | SHA-256 |
|---|---|
| 55 | `7fe1e2b2a427da920756e0db1fa768300fac7602c2855cb9d07b50a9e23aab9f` |
| 57 | `16a22832d6275e3627e05c7f612f35d31f53248f4c9c34a2d47a68ed3cdb0132` |
| 58 | `a14c0a1c64bdb74df13a417808b0f8b8d1eddd404e1afca0b49a8ac86993affd` |
| 59 | `d7ce9a7e58823bd6199c55922b540bf12d89fa5143c64d02cc4115a91ec0cec5` |
| 60 | `63b770ec440163f722b49f95fd104ea9bae8c7e577587b364bb9a814dd5adc58` |


## Revision record — 25 October 2026

Claude independently reviewed the notebook, repository instructions, input files and archive. It verified source/output transcription, source hashes, RNG sequence, input identities and bridge invariants, and identified two specification blockers: missing mixed-outcome/finalisation semantics and unpinned panel CSVs. This revision addresses both. It also incorporates the environment-history cells, six-name mapping observation, possible libsvm RNG limitation, explicit character-ID handling, missing source output and alternate-branch clarification. Review conclusions do not constitute executed ML reproduction.

## Implementation-review revision — B1–B4

Samuel authorised global notebook evaluation with local wrapper state, validation
of data-frame or matrix probabilities without replacing original objects, and
independent model continuation after training/validation failures. The revised
runner asserts the default RNG kind and split-to-RF state continuity. Historical
AUC agreement uses seven significant digits (the notebook's print precision),
not three decimal places. Unknown historical package versions and unresolved
SVM probability repeatability limit interpretation but do not block one faithful
execution. Dependency/build/lock readiness and independent code review still do.
