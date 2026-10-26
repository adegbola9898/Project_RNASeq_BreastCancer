# Baseline manuscript-to-source reconciliation

26 October 2026, Africa/Lagos. Documentation-only reconciliation first written at
repository HEAD `db8fb67` on `analysis/initial-review`, then updated after the
single four-model manuscript replay at commit
`40926994f7e45aa2eb8dce8657a490f51d1316c3` (see
[Executed replay results](#executed-replay-results)). No network reconstruction,
manuscript editing or original-input modification was performed. This ledger
separates numerical reproduction from scientific validation.

## Sources, identity and interpretation

The supplied inputs remain outside the repository, unchanged, under
`/home/samuel/wgcna-evidence-20261024/manuscript-reconciliation-inputs/`:

| Input | SHA-256 |
| --- | --- |
| Machine_Learn.ipynb | `24f7b02dd302afc48d695fdf7cb6b26968edd6b4b63212c28d33d2a3c6f6c1a1` |
| Adegbola_et_al2.pdf | `0963ede3e17f51e560489d09aaf40a425ee422e1b80c3a11f171325cb26abafd` |

`Machine_Learn.ipynb:Zone.Identifier` was ignored. Cell references below use
one-based JSON positions, including empty cells. **ML** means the supplied
Machine_Learn notebook; **Manu** means the preserved
`notebooks/original/Original_Manu_Pipe.ipynb` (SHA-256
`ca9671af2eb21bf551641d1e01bfebef5926c1547fee60c86e6bc06caff2f45c`).
All 197 ML execution counts are null; its R kernel metadata coexists with Python
source cells. Saved text/images do not establish a continuous execution history.

PDF references are physical pages 1–8, verified from the page tree. No installed
PDF renderer/text library was available. Text was read from the local PDF's
Flate-compressed content streams using Python's standard library, without an
installation or network lookup. This exposed prose, table text and captions;
font-encoded mathematical spans and embedded figures were not fully decoded or
visually verified. Exact missing mathematical thresholds and figure appearance
remain unverified. No claim below relies on reconstructing those omitted glyphs.

Classification vocabulary:

- **Reproduced:** a fresh baseline artifact/log supports the stated numerical
  checkpoint, within the explicitly stated precision and audit limits.
- **Historical-only:** source/saved notebook output supports the observation,
  but no fresh fitting/evaluation evidence in the inspected material establishes reproduction.
- **Discrepant:** manuscript/source branches or fresh evidence contradict the
  stated method/number. Agreement elsewhere does not erase the discrepancy.
- **Unsupported:** sufficient source, retained evidence or inferential support
  is absent from this bounded evidence set. This is not proof of global absence.

Existing evidence roots used here:

- **P:** repository `Results/baseline_preprocessing/run-20261013T053229Z-205981/`,
  including completed provenance, matrix/metadata RDS, session and execution log;
  see [completed preprocessing record](baseline_preprocessing.md#completed-baseline-run-and-independent-review).
- **W:** `/home/samuel/wgcna-evidence-20261024/baseline-review/baseline/`, the
  small review copy of original WGCNA artifacts/log/provenance/manifest.
- **A:** sibling `audit/`, especially audit-summary.json and r-checks.csv.
- **H:** sibling `recovery/`, especially recovery_provenance.txt and the recovered
  module_trait_heatmap.png. This is a separate visualization, not a repaired run.
- **V:** `/home/samuel/wgcna-evidence-20261024/verification.json`, recording archive
  SHA-256 `f1bb9b76a5316dffbed5a80bf5449185280ca7a5d3035336c2ea46a922de92a9`,
  verified transfer integrity, complete monitoring evidence and **incomplete** run
  classification. This task read the existing verification report; it did not
  repeat hashing/verification of the 2.52 GB archive or reload its TOM.

W corresponds to VM run `run-20261024T120729Z-46759`, implementation
`8553d820db26c03f942166864aa3ae198548a804`. All selected analytical stages finished,
but output validation failed. A reports 105 PASS, 2 FAIL and 12 NOT_PERFORMED;
the two failures are two checks of the same missing heatmap. Original live-object
identity and unsaved IMC checks remain not performed. V verifies 27 original
manifest entries; neither that count nor the valid saved outputs establishes
runner completion. No COMPLETED is created or inferred.

## Manuscript claim ledger

| ID / manuscript location | Claim | Source / saved-output mapping | Existing reproduction evidence and classification |
| --- | --- | --- | --- |
| C01 — abstract p1; Methods/Table 1 p2 | Three GEO datasets, 279 samples, 39,376 starting genes; 25,750 retained | Manu 2 Chunks 2–4; ML 49 and 68–70 show downstream dimensions | **Reproduced** for analytical input dimensions and 25,750 retained (~65.4%). P and preprocessing record establish these checkpoints. Table 1's original/excluded counts and historical exclusion reasons are **unsupported** by this check; do not invent them or reopen the parked sample-count issue. |
| C02 — Methods p2, Results p3 | DESeq2 design ~ batch + Subtype, VST blind=FALSE; pre-correction median 7.61, range 1.67–23.42 | Manu 2 Chunk 5 | **Reproduced** at displayed precision: P log min 1.671, median 7.614, max 23.421. Manuscript DESeq2 v1.40 differs from reproduction 1.48.2: **discrepant environment**, not recovered historical version. Corrected expression can be negative; do not apply the pre-correction range to it. |
| C03 — Methods p2; Fig. 2 p3 | PCA before/after correction; 93% PC1 before, 45%/11% after; successful biological segregation | Manu 2 Chunks 5–6; P PCA images and completed preprocessing | PCA generation/top-500 procedure is **reproduced**. The exact three variance percentages were not independently extracted from saved PCA objects here: **historical-only** numerical claims pending bounded artifact inspection. Removing confounding or establishing biological validity from visual clustering is **unsupported**; subtype was explicitly preserved and is strongly associated with study. |
| C04 — Methods p2; Results p3 | A signed WGCNA construction, power 6, min module 30, merge height .25 | Manu 3,5; W soft_thresholding_results.csv, execution log and source settings | Power/settings are **reproduced**. Pure signed construction is **discrepant**: networkType is omitted (unsigned default), TOMType is signed, with WGCNA 1.74 native AdjTypeUnsignedKeepSign; later cell 13 uses signed adjacency. Power 6 is explicitly selected, not an automatic optimum. Saved power-6 SFT.R.sq is 0.812071641687434 and mean.k. 1086.32890188289; preserve these values rather than substitute a theoretical criterion. |
| C05 — abstract p1; Results p3 | 20 modules, size 33 lightyellow to 7,346 turquoise | Manu 5–6; W module_summary.csv and log | **Reproduced** as 20 color groups **including grey** (2,876 unassigned genes); not 20 non-grey biological modules. Sizes sum to 25,750. This count does not prove robust functional modules. |
| C06 — Results p3 | 345 loosely connected genes pruned at low kME | Manu 5's saved removal messages; W cell-5 removal messages | **Discrepant:** both historical and fresh logs have 19 removal messages totalling **302**, not 345. This is a message-count reconciliation, not independent re-evaluation of individual kME thresholds or retained-gene identities. |
| C07 — Methods pp2–3; Results pp3–4; Fig. 3 p4 | Correlations/FDR identify subtype-associated modules and exported genes | Manu 9–10; W module_trait_correlations/pvalues/FDR/summary CSVs and log | **Reproduced** numerical checkpoints: ERpos black .858/brown .593; TNBC greenyellow .776/midnightblue .517/grey60 .413; HER2pos blue .807. Exported sets ERpos 3,781, TNBC 321, HER2pos 9,074 match W. These are overlapping FDR-selected module unions, not the final uniquely assigned panel; associations include negative correlations. |
| C08 — Fig. 3 p4 and heatmap references | Module–trait heatmap produced | Manu 9; W correlation CSV, original missing PNG; H recovered PNG/provenance | **Discrepant** original output contract: required PNG absent; original run exits 1 and stays incomplete. **Reproduced** separate visualization from saved 20×3 CSV: H records silent pheatmap/gtable drawing, 3600×2400 and source hash unchanged. Recovery cannot validate original in-memory equality or backdate completion. |
| C09 — Results p4 | kWithin median 230.7, mean 421.6, range .36–2145.2; kME–kWithin r=.445 | Manu 13,15–16; W degree_stats, kME_table, log/masterNodes (latter retained in full archive) | **Reproduced** log checkpoints: 230.6555, 421.5569, .3622–2145.2327 and .445. Provisional positional kME remapping remains scientifically unresolved; A cannot validate original live IMC or kME identity. Those numbers do not establish a corrected membership analysis or a demonstrated scale-free distribution. |
| C10 — Methods p3; Results p4 | Top 50 per subtype / top 20 per subtype yields 350; strongest-correlation module assignment | Manu 47 explicit final_assignments; W final_hub_genes*.csv | **Discrepant selection description**, although **reproduced panel size**: seven manual module–subtype pairs ×50; ERpos 100, TNBC 100, HER2pos 150. Modules are greenyellow/midnightblue (TNBC), yellow/magenta/blue (HER2pos), black/brown (ERpos). Source does not compute strongest-correlation assignments. The saved order/IDs are pinned in the ML spec; project-reported top-50 check is attributed there, not repeated here. |
| C11 — ML Methods p3 | 80% training / 20% test | ML 70 and 120; repeated R count outputs 7,14,21 | **Discrepant:** R source p=.7 and saved 198/81 (caret's stratification rounding). Python 50 instead yields 195/84; neither is 80/20. Exact historical sample membership is unavailable. |
| C12 — Results p4; Fig. 4B p5 | RF/SVM accuracy ~98.8%, macro F1 ~.98/.981 | ML 3/10 and 71/72; 120 repeats fits; 2 hardcodes summary bars | **Reproduced** accuracy, macro F1 and full confusion matrices: replay R1 gives RF/SVM .9876543=80/81, macro F1 .9805097, matrices identical to ML 71/72 and 120. Per-class positional AUCs agree with ML 120 but **disagree** with ML 71/72 (see AUC attribution); SVM AUCs use misaligned probability columns. Cell 2 is a literal summary, not computed evidence. Manu 58 RF instead 79/81 (.975), reproduced by Manu run M1; that older branch remains **discrepant** as an explanation of the manuscript's RF number. |
| C13 — same locations | LR accuracy ~96.3%, macro F1 ~.92/.925 | ML 17,73 and 120; summary 2 | **Reproduced:** replay R1 LR 78/81=.962963, macro F1 .9248918, matrix identical to ML 73/120; positional AUCs agree with both ML 73 and 120. Here LR is direct nnet::multinom, MaxNWts=5000. Manu 60 is caret train(method="multinom") with omitted limits; Manu run M1 reproduced its stopping error (all 75 resample fits: "too many (1408) weights"), so that three-model runner cannot reproduce this claim by construction. |
| C14 — same locations | XGBoost accuracy ~97.5%, macro F1 ~.97 | ML 23,74 and 120; summary 2; exports 28 | **Reproduced** with reproduction version xgboost 1.7.11.1: replay R1 79/81=.9753086, macro F1 .9698322, matrix identical to ML 74/120; positional AUCs agree with both ML 74 and 120. The manuscript's coarse 1.6 is not recovered: 1.6.0.1 is API-compatible but does not build unmodified here. No historical fitted-model bytes were verified. |
| C15 — Fig. 4B p5 | .25 chance line for four balanced classes | ML 2 literal chance=1/4; ML 70 count table | **Discrepant** balance description: test classes ER+12, HER2+48, Normal7, TNBC14. .25 is a uniform random-guess reference; the majority-class/no-information accuracy is 48/81=.5925926. Neither line proves independent predictive usefulness. |
| C16 — ML Methods p3 | Model versions caret6.0, RF4.7, e1071.7, nnet7.3, xgboost1.6 and saved reproducibility objects | ML library/install history and 8,13,20,28 CSV writes; Manu 48/52 bridge saves | **Historical-only** coarse version statements, not an exact recoverable lock/session. Reproduction versions (randomForest 4.7-1.2, caret 7.0-1, e1071 1.7-17, nnet 7.3-20, pROC 1.19.1, xgboost 1.7.11.1) are new locks, not recovered history. Replay R1 rewrote the 8/13/20/28 CSVs from fresh predictions; historical CSV files remain unverified. The scoped earlier absent-file search is documented in the ML spec; no new global search or assertion of absence was made. Saved final panel is real; WGCNA_ML_inputs.RData cannot be presumed available. |
| C17 — Methods p3; Results/Discussion pp4,6–7 | Independently validated predictive/clinical power and robustness | Full-cohort Manu preprocessing/WGCNA/panel precedes ML split; ML 70 | **Unsupported** inference: full-cohort label-informed feature selection, full-cohort preprocessing, random sample split without patient/study grouping, known repeated patients and study–label confounding. Normal is a tissue category, not an intrinsic tumour subtype. Even exact metric reproduction would not establish independent/clinical validation. |
| C18 — abstract p1; Results p4; Discussion pp6–7 | 48% literature-supported hubs, endocrine resistance34%, HER2 immune >50%, random-gene enrichment significance | PDF prose/references; no corresponding computation in selected Manu or ML branch | **Unsupported** as reproducible quantitative results in supplied evidence: no gene-level adjudication ledger, denominator/overlap rules, query history, random comparison sample/statistic or test output was identified. Citations alone cannot establish these fractions or enrichment. No literature research was conducted here. |
| C19 — Figs. 4A/4C p5, Fig. 5 p6; Discussion pp6–7 | Biological network diagrams, actionable targets, liquid biopsy/drug utility and mechanistic/clinical benefit | PDF captions; ML 75–77 importance and 79/124–125 overlap are different analyses | **Unsupported** from this reproduction evidence: exact diagram construction, edge threshold/layout/annotation and clinical/functional validation are not supplied by those importance/overlap cells. Literature hypotheses need a separate evidence ledger; no assay/trial validity follows from these fitted-expression classifiers. |

## Separate historical branches and numerical checkpoints

The supplied notebook explains the manuscript much better than substituting the
older Manu branch. Do not blend their scores, class orders, seeds or model types.

| Branch | Split and class order | RF / SVM / LR / XGB evidence |
| --- | --- | --- |
| Manu 55→57→58→59→60, existing runner | Normal, ERpos, TNBC, HER2pos; 198/81 | RF79/81; SVM80/81; caret LR stopping error; no XGB. Its selected cells reset SVM/LR seeds separately. |
| ML R 68–74, echoed in 120 | as.factor(category): ER+, HER2+, Normal, TNBC; 198/81 | RF80/81; SVM80/81; direct nnet LR78/81; XGB79/81. Only split has explicit seed2024; model RNG continues in branch order. |
| ML Python 48–54 | sklearn stratified195/84, different samples/order | RF/SVM saved matrices each82/84; support and metrics differ. This is alternate history, not the manuscript's R denominator. |

R test class counts in order ER+, HER2+, Normal, TNBC are 12,48,7,14;
training counts are 30,115,19,34. ML 71–74 save the following confusion matrices
(prediction rows, reference columns, same class order):

```text
RF and SVM:              LR:                     XGB:
11  0  0  0              10  0  0  0              11  0  0  0
 0 48  0  0               0 48  0  0               0 47  0  0
 0  0  7  0               1  0  6  0               0  0  7  0
 1  0  0 14               1  0  1 14               1  1  0 14
```

Macro F1 values .9805097/.9805097/.9248918/.9698322 are printed in ML
3/10/17/23; their rounded display explains cell 2 and Fig. 4B. Arithmetic from
these confusion matrices supports the correspondence; it is not new prediction.

Do not import Manu's printed perfect AUCs into this notebook. The notebook holds
**two saved sets** of positional per-class AUCs for this branch: the split cells
ML 71–74 and the combined cell ML 120 (SHA-256
`a7006a01515d315d478dbbaf5e5e4cf5cdfa6c1fd18ec40b08a7f2d16b12fc6f`; a separate
cell whose text differs from 68–74 but carries the same four-model spine). In
class order ER+, HER2+, Normal, TNBC, compared with replay R1 at the seven
printed significant digits (agreement = |difference| < 5e-8):

| Model | ML 71–74 (split cell) | ML 120 | Replay R1 | R1 vs split cell | R1 vs 120 |
| --- | --- | --- | --- | --- | --- |
| RF | 71: .9818841, 1, 1, .9978678 | .9903382, 1, 1, .9978678 | .9903382, 1, 1, .9978678 | disagree (ER+ .00845) | agree |
| SVM | 72: .7934783, .9772727, .7239382, .7857143 | .7971014, .9753788, .7413127, .7910448 | .7971014, .9753788, .7413127, .7910448 | disagree (max .0174) | agree |
| LR | 73: .9263285, 1, .9980695, .9861407 | same as 73 | same as 73 | agree | agree |
| XGB | 74: .9794686, 1, 1, .9904051 | same as 74 | same as 74 | agree | agree |

ML 71/72 and ML 120 therefore disagree with each other for RF and SVM AUCs, while
their printed accuracies, confusion matrices and (ML 70/120) split counts agree.
Both are **historical-only** saved outputs; neither is preferred. No cause for the
difference between the two saved sets is asserted. The replay runner's built-in
AUC checkpoint used ML 71–74 and so reports RF/SVM `differs_from_checkpoint`;
that label is correct for those cells and is not a disagreement with ML 120.

SVM ROC messages include reversed directions in ML 72, ML 120 and R1. R1 captured
the actual SVM probability column order **Normal, ER+, TNBC, HER2+** against
positional labels ER+, HER2+, Normal, TNBC, so the SVM positional AUCs pair
classes with the wrong columns (R1 diagnostic `column_alignment = mismatch`).
RF and LR columns are aligned; XGB's source reshape leaves them unlabelled. The
faithful values are preserved; a named-column repair is a separately identified
correction. The source also leaves ROC levels/direction automatic and max.col tie
handling omitted.

## Smallest coherent four-model R workflow

Propose **ML 68 (trusted-input bridge only) → 69 → 70 → 71 → 72 → 73 → 74**,
with metrics/exports reused from 3/8,10/13,17/20,23/28 **without fitting again**.
This is a proposed explicit reconstruction, not proof of historical session order.
Cell 120 is a useful cross-check containing the same four-model spine, but ends
with a saved optional-feature-importance error: xgb_mod$feature_importances has
length zero against 350 genes. Prefer 76's xgb.importance if that optional plot
is separately required; do not run a second set of model fits to reach it.

The minimal execution contract requiring review is:

1. Use the existing pinned expression RDS, aligned metadata and both panel CSVs
   from the [ML spec](baseline-ml-reproduction-spec.md#4-input-bridge-and-invariants).
   Do not rerun preprocessing/WGCNA or use an unverified /content/expr.csv copy.
   Replace ML 68's positional metadata-row assignment with an explicit assertion
   of sample identity/order. Bridge Subtype back to category **by value**:
   Normal→Normal, ERpos→ER+, TNBC→TNBC, HER2pos→HER2+; then preserve ML 70's
   as.factor order. Save this mapping, input hashes and feature-name mapping.
   Do not silently inherit the older runner's factor order or make.names policy;
   record/check the selected loader's actual names and stop on ambiguity.
2. Cell 70: set.seed(2024), createDataPartition(p=.7,list=FALSE), single shared
   split. Keep exact sample/gene/label order, training/test IDs and RNG snapshots.
   RF is the x/y interface, ntree1000/importanceTRUE; SVM radial/probabilityTRUE;
   LR direct multinom with traceFALSE/MaxNWts5000; XGB multi:softprob,
   num_class4,nrounds100,max_depth6,eta.1,verbose0 and source probability reshape.
   Preserve omitted defaults, native probability RNG uncertainty and tie handling.
   Do not insert the existing Manu runner's SVM/LR seed resets. Source metric
   computations between fits must not be reordered if they consume RNG.
3. Attempt each independent branch once; preparation/split failure stops all.
   Preserve warnings, errors, effective defaults, branch training/validation
   statuses, fitted objects, predictions, probability columns, truth and RNG.
   When a source failure prevents completion, report it instead of repairing it.
   An earlier failure changes the later continued RNG history; record that limit
   and never compare the continuation as an identical historical session.
4. Derive full confusion matrices, per-class metrics and macro F1 from saved
   predictions; preserve source ROC outputs/directions/class-order checks. Export
   the named RF/SVM/LR/XGB confusion_matrix/per_class_metrics/per_class_auc CSVs
   specified in 8/13/20/28, plus identifiers and model evidence. Render Fig. 4B
   from those measured results, not cell 2's literals. Close devices, validate
   read-backs and finalize a manifest/audit record in a new ignored run directory.
   Mixed failures remain explicit; no original WGCNA marker/manifest is changed.

This four-model route is implemented separately by
`scripts/baseline/manuscript-ml.R` ([handoff](baseline-manuscript-ml.md)); the
source-faithful older three-model `scripts/baseline/ml.R` is preserved unchanged.
XGBoost 1.7.11.1 was added in a separate reviewed lock that retains all 149 Manu
extension records, including the 113 baseline records.

Selected-cell source hashes (UTF-8 source strings concatenated exactly):

| ML cell | SHA-256 |
| --- | --- |
| 68 | `e42d1230e49eaec4131ebe2cf647c98167fd937eab339889caac9128526444f9` |
| 69 | `760896b94616842773aa1075a7893f5c4c3c9cec78205e33efa7576c6dbd8e2e` |
| 70 | `6008f341a1d62e766a034e7a2d715160ffba80622bd15b3a8765a3f7b8833d23` |
| 71 | `c1571e35ca43ef15109755c914aa9bba56531a7f1fec6270195ebdb36f4dbdd1` |
| 72 | `78326881d8ce0820bea9095527742ce3a47c63e51fd0b13e7d70c87f5db14632` |
| 73 | `c5b3792f77bde7a6d16732ee8c7af142edc605a95431095f4da91d9a015c39ff` |
| 74 | `433bd46aaf962f93dbdec1d9ef8f57617049a50fdba0585e0dda9d7a84e4d53d` |

## Minimal remaining execution and baseline closure

The one fresh, provenance-captured four-model R run on the existing 350-gene
panel has been executed once (R1, below); no tuning, repeatability experiment,
Python branch or second R history was run. The older three-model replay (M1) was
executed separately for its own subtask.

Use existing WGCNA audit/recovery evidence; do not reconstruct its network to
change the original failed status or fill impossible live-object identity checks.
For upstream numerical claims not resolved here (notably PCA percentages), use
saved provenance/plot labels where sufficient; otherwise mark unsupported or
historical-only rather than recompute the pipeline. Literature fractions,
clinical validation and network diagrams must be documented from genuine retained
evidence or removed/qualified through scientific review. They do not create an
open-ended obligation to run new biology to close a **baseline** ledger.

Successful baseline closure can mean reproduced checkpoints **or documented
failure/discrepancy**, with explicit review acceptance. It never means that the
manuscript's independent/clinical validation claims have been validated. ML
accuracy, macro F1 and confusion matrices are now classified reproduced for the
manuscript R branch (C12–C14); RF/SVM AUC agreement depends on which saved
notebook cell is compared, and both are recorded.

## Executed replay results

Both runs were executed once from clean committed trees on `analysis/initial-review`.
Evidence paths and SHA-256 values are listed in the
[release inventory](baseline-release-inventory.md).

**R1 — four-model manuscript replay.** Commit
`40926994f7e45aa2eb8dce8657a490f51d1316c3`; run
`Results/baseline_manuscript_ml/run-20261026T113840Z-17527/`; exit 0,
`workflow_status = finished_all_models_succeeded`, `diagnostic_status =
review_required` (SVM column mismatch; XGB unlabelled). Split 198/81 with training
30/115/19/34 and test 12/48/7/14 (ER+, HER2+, Normal, TNBC) matches ML 70.

| Model | Status | Accuracy | Macro F1 | Accuracy/F1 | Confusion | Positional AUC |
| --- | --- | ---: | ---: | --- | --- | --- |
| RF | succeeded | .9876543 (80/81) | .9805097 | match | match | ML 120 agree; ML 71 disagree |
| SVM | succeeded | .9876543 (80/81) | .9805097 | match | match | ML 120 agree; ML 72 disagree |
| LR | succeeded | .9629630 (78/81) | .9248918 | match | match | ML 73 and 120 agree |
| XGB | succeeded | .9753086 (79/81) | .9698322 | match | match | ML 74 and 120 agree |

Finalisation/integrity: 42-entry `artifact_checksums.csv` (SHA-256
`f145768b36ad16fba24fd893fcffe2a4612c5ffb2ea0470ae2dd4ada03ad2e7c`)
independently re-verified for exact file set, byte counts and hashes;
`review-finalization.json` records that manifest hash; no
`finalization_failure.txt` and no COMPLETED by design. RNG state was identical at
every model boundary; no warnings. The run recorded xgboost 1.7.11.1, the
manuscript lock (`c5f429e1…`) and the API review record (`f38de57d…`). Console,
timing and exit-code logs are in the manuscript dependency bundle
(`execution-logs/`): 10.19 s wall clock, 558,412 kB maximum resident set size.

**M1 — older three-model Manu replay.** Commit
`db8fb67a089842d3c07359dfd24ca2dee1ad2ae7`; run
`Results/baseline_ml/run-20261026T073318Z-86649/`; exit 3,
`finished_with_model_failure`. RF 79/81 and SVM 80/81 succeeded with confusion
matrices and printed AUCs matching Manu 58/59; caret LR failed in training
(Manu 60's error class reproduced). 31-entry manifest
`1b50e012044a64402a74f323412627461eb05e085dc97bc7a8d0c2cd60c40163` verified. Its
external console/timing logs were not preserved (see inventory); in-run
execution.log and provenance survive.

Limitations of both runs: inputs are the pinned preprocessing RDS (full
precision), not the historical `/content/*.csv` files; package versions are
reproduction locks, not recovered sessions; matching metrics do not establish
historical sample membership or fitted-model identity; leakage, repeated-patient
and study/category confounding limits (C17) are unchanged.

## Checks performed for this document

Read the two supplied inputs, repository instructions and baseline docs/source,
small WGCNA review CSVs/logs/provenance summaries, existing audit/recovery reports
and transfer verification JSON. Checked notebook cell identities/source hashes,
metric/denominator correspondence, module-size and panel-count arithmetic, and
low-kME removal-message sums in historical and fresh logs. Input hashes were
checked again after documentation; both remained unchanged. Checked all 19 claim
IDs, selected cell hashes, local documentation link targets and whitespace.
No source notebook, R runner, audit, recovery or model was executed. Only this
new document is changed; temporary text extraction stayed under /tmp.

## Checks performed for the post-execution update

Read-only: compared R1 saved evidence with every saved ML cell output containing
the AUC values (only ML 71–74 and 120 do), at |difference| < 5e-8; re-verified the
R1 and M1 manifests; re-checked the WGCNA archive against its SHA-256 sidecar and
generated the inventory hashes. No model, preprocessing or WGCNA step was run.

## RC1 dispositions and patient-overlap completion

The current release request accepts preservation of the two conflicting
historical AUC sets without preference, the reproduced SVM column defect,
incomplete original WGCNA plus separate recovery, unsupported claims remaining
unsupported, and lost external Manu logs with surviving in-run evidence. These
are baseline dispositions, not approval of independent or clinical validity.
[RC1](baseline-release-candidate.md) records the exact narrowed acceptance:
**one-command verification of frozen evidence**, never a clean-clone rebuild.
Stage replay instructions remain [separate](baseline-stage-replay.md).

The required read-only audit now joins both saved split ID sets to
sample_provenance.csv: M1 shares 28 reported patients across training/test; R1
shares 31. Both have 88 training and 33 test samples with unknown patient identity.
Exact IDs, partitions and source hashes are preserved in
release/baseline-rc1/patient-audit/. This establishes known leakage, not
independence among samples without reported identity. Neither model was refitted.

## Finite release checklist

- [x] Four-model source, dependencies, execution and saved metrics reviewed as
  recorded above; retain all source and probability-order limitations.
- [x] Known/unknown patient identity audited from saved IDs for both ML runs.
- [x] Exact locks and XGBoost review/build references preserved in release paths.
- [x] Conflicting historical AUCs, SVM defect, incomplete WGCNA, unsupported claims
  and surviving-versus-lost Manu evidence have explicit accepted baseline dispositions.
- [x] Acceptance narrowed to frozen-evidence verification; stage replay separate.
- [x] Implement a portable local layout and verifier; the actual local verification
  verdict is recorded in release/baseline-rc1/verification-result.json, not inferred
  from any all-stage-success claim.
- [ ] Claude reviews RC1, verifier, frozen index and limitations independently.
- [ ] Establish archival custodian/retention and verify a second preserved copy
  after authorised transfer. No public location is assumed.
- [ ] Obtain separate commit/push/tag authority. Corrected scientific validation
  remains a distinct future task and is not part of this release acceptance.
