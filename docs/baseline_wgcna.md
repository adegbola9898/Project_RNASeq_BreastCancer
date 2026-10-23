# Original baseline WGCNA: network, associations and hub selection

The original extraction was documentation only. The faithful runner is now implemented in `scripts/baseline/wgcna.R`, but has not been executed. All WGCNA results quoted below are **historical saved notebook outputs**, not newly reproduced results. The completed preprocessing run is documented separately in `docs/baseline_preprocessing.md`; its success does not establish WGCNA or scientific validation. Scope stops at module/category association and hub-gene selection. ML, enrichment, GSVA, GNN and edge-list export workflows are excluded.

Cell references are **one-based JSON `cells` array positions**, including all cell types; subtract one for the zero-based index. The relevant cells have null execution counts, so positions do not prove execution order or a fresh-session execution history. Code blocks in the appendix are verbatim whole cells or explicitly labelled contiguous excerpts. Comments are preserved as narrative claims, not automatically accepted as method evidence.

## Sources and continuity

Primary source: `notebooks/original/Original_Manu_Pipe.ipynb` (Manu below). The selected preprocessing cell 2 ends with `expr <- t(assay(vsd))`, after replacing the VST assay with batch-corrected expression. Thus `expr` is samples × genes and `metadata` is in the same sample order, with batch levels GSE243375/GSE52194/GSE58135 and Subtype levels Normal/ERpos/TNBC/HER2pos (Normal reference).

The reviewed preprocessing implementation saved equivalent endpoint objects at `Results/baseline_preprocessing/run-20261013T053229Z-205981/expression_samples_by_genes.rds` and `aligned_metadata.rds`. These are new preprocessing outputs, not historical WGCNA inputs/results. The original WGCNA cells use objects already in memory; they contain no `readRDS` bridge to this new run directory. The authorized runner now adds this fresh-process bridge as an explicit implementation adaptation. Do not clip its negative corrected expression values or transpose `expr` again.

| Primary cells | Role and continuity |
| --- | --- |
| 1, 2 | WGCNA setup/correlation binding; selected preprocessing produces `expr` and `metadata`. |
| 3–4 | Signed soft-threshold exploration on `expr`, `sft`, `sft_df`. |
| 5–6 | `softPower`, `net`, module sizes and `MEs` from `net$MEs`. |
| 8–10 | Dendrogram/eigengene plots, module–Subtype association, FDR module selection and `geneMod` lookup. |
| 13–17, 19–22 | Separately recomputed signed adjacency, `IMC`, `kMEtab`, `masterNodes`, rankings and subtype node exports. |
| 26 (hub-selection excerpt), 28 | Global top-50-per-module and overlapping subtype top-50-per-module hub variants. |
| 47 | Explicit seven-pair final hub panel, before any model fitting. |
| 93, 107, 111–112, 119 | Later alternative selection/association/plot/report cells that reuse or overwrite earlier objects/files. |

Alternative source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb` (February below), especially cells 2–3, 5–6, 11, 13–18. Its preprocessing cell 1 creates a samples × genes object named `data`, retains `category`, and differs from selected Manu preprocessing. Neither `Project_RNASeq_BreastCancer.ipynb` nor `Untitled7.ipynb` contains a WGCNA workflow; their upstream preparation must not be substituted for a missing WGCNA step.

## Project decision: selected faithful baseline

Continue from completed preprocessing **Manu cell 2** using **cells 3 → 5 → 6 → 9 → 10 → 13 → 15 → 16 → 47**, in that order. This is the selected implementation specification. Implementation has now been authorized; execution remains separately gated. **Include cell 1’s non-install session setup in the faithful baseline:** `library(WGCNA)`, `enableWGCNAThreads()` and `cor <- WGCNA::cor`, as quoted in the existing setup excerpt. Package installation commands remain excluded. This session setup accompanies the unchanged analytical path above; cell 1 must not be executed wholesale as an installation script.

Cells **17, 19–22, 26 (prefix) and 28** are optional historical exports, not required baseline steps. Cell 4 and the later alternate-label/reporting branches, including 93, 107, 111–112 and 119, remain comparison evidence outside the selected path; February variants are also excluded from the selected implementation. Cell 8 and the cell 18 diagnostic are not in the selected path either. The appendix includes these sources for review, not as extra required steps.

Preserve duplicated candidate powers, hard-coded power 6, the `networkType` omission in `blockwiseModules`, turquoise exclusion and **cell 15 exactly as written**, including its potentially problematic color remapping. Any methodological correction belongs to a separately identified analysis, not this faithful baseline. Cell 47 defines a **historical manually assigned 350-gene panel**, not a validated or uniformly selected subtype-specific panel.

Historical network defaults and actual session order remain unknown. Future execution must record the **thread configuration, locked WGCNA version and effective omitted defaults** of the called functions, alongside session information. Preserve `enableWGCNAThreads()` without an explicit count; record the effective thread configuration rather than assuming it matches the historical seven-thread log. That records the new reproduction environment; it does not recover historical defaults or prove that the numbered cells originally ran in this order.

## Quality checks, exclusions and missing data

No explicit WGCNA-stage `goodSamplesGenes` call, sample-clustering call, sample dendrogram cut, outlier-removal threshold, patient grouping or sample exclusion list is present in these workflows. The gene dendrograms in Manu cells 8/111 are network gene clustering, not sample clustering; PCA from preprocessing is not an outlier-removal rule. The existing count filter belongs to preprocessing and is not a second WGCNA gene filter.

Manu cell 5's saved log shows internal `blockwiseModules` missing-value flagging and a single block. It also reports low-kME removals **from modules**, such as 140 genes from module 1 and 70 from module 2. These logs do not establish input-gene deletion, a new count filter, or documented sample exclusions. `net` exposes `goodSamples` and `goodGenes`, but the source does not explicitly report these vectors or subset `expr`/`metadata` by them. Internal missing-value, eigengene imputation and quality thresholds are omitted package defaults; their historical effective values remain unresolved.

Explicit safeguards: cell 9 requires `identical(rownames(MEs), rownames(metadata))`; cell 10 checks module-color vector length against `ncol(expr)`; cell 13 checks sample/ME row counts and gene/color lengths but not all ID equality; cell 16 stops on missing assigned-module kME for non-grey/gold modules; cell 20 checks exported colors. Trait/eigengene correlations use pairwise-complete observations, but Student p-values always receive `nrow(metadata)`, not a pair-specific nonmissing sample count. No explicit missing-value repair is supplied. February cell 6 checks row-name equality and cell 16 checks TOM dimensions, not gene-name identity.

## Soft threshold and network construction

Manu cell 1 attaches WGCNA last, calls `enableWGCNAThreads()` with no thread count, and binds `cor <- WGCNA::cor`. Cell 3 calls `pickSoftThreshold(expr, powerVector = powers, networkType = "signed", verbose = 5)` with `powers <- c(1:20, seq(12,50,2))`. This is 40 candidate entries including repeated powers 12, 14, 16, 18 and 20; do not deduplicate it silently.

The topology plot draws a horizontal line at 0.8, but there is **no executable automatic selection rule**, no explicit `RsquaredCut`, and no assignment from `sft$powerEstimate`. Cell 5 hard-codes **`softPower <- 6`**. The saved table's power-6 SFT.R.sq is 0.81207164 (power 5: 0.77468161), so first-crossing-0.8 is a plausible reading of the plot, not a recovered selection algorithm. Actual executable power is 6, also repeated in cell 13 and February cells 2/18.

All explicitly supplied Manu cell 5 construction parameters:

| Argument | Exact source value |
| --- | --- |
| Data | `expr` (samples × genes) |
| `power` | `softPower`, assigned 6 |
| `maxBlockSize` | 26000 |
| `TOMType` | `"signed"` |
| `minModuleSize` | 30 |
| `reassignThreshold` | 0 |
| `mergeCutHeight` | 0.25 |
| `numericLabels` | FALSE |
| `randomSeed` | 1234 |
| `saveTOMs` | TRUE |
| `saveTOMFileBase` | `"TOM"` |
| `verbose` | 3 |

**`networkType` is omitted from `blockwiseModules`**, despite being explicitly signed for threshold exploration and later adjacency. `TOMType = "signed"` must not be treated as an explicit signed adjacency/network argument. The selected faithful baseline preserves this omission. Any correction requires a separately identified analysis; the historical default is not resolved by assuming the narrative intended a signed network.

Tree-cut/PAM settings (`deepSplit`, `detectCutHeight`, `pamStage`, `pamRespectsDendro`) are omitted. So are `corType`, `corOptions`, `maxPOutliers`, `TOMDenom`, TOM suppression settings, explicit blocks/preclustering settings, missing-value/imputation settings, kME retention/core thresholds and thread count. No standalone dynamic-tree-cut or merge call is executed by these cells; those operations are internal to `blockwiseModules`. `randomSeed = 1234` is the only explicit network seed; there is no in-scope `set.seed` call. A saved log reports 7 parallel threads and one block, not an explicit source thread/block assignment.

Manu cell 13 separately creates `adjMat <- adjacency(expr, power = softPower, type = "signed")` and `IMC <- intramodularConnectivity(adjMat, moduleColors)`. This signed adjacency is used for hub rankings, not passed back into cell 5's module detection. Adjacency correlation function/options and connectivity scaling/unassigned-color settings are omitted. The optional TOM size assertion is commented out. No Manu WGCNA-stage standalone `TOMsimilarity` call exists.

## Eigengenes and module/category association

Manu cell 6 uses `MEs <- orderMEs(net$MEs)`, not a separately parameterized `moduleEigengenes` call. Its comment says alphabetical colors/grey last, but the displayed order begins pink/black/brown/lightgreen/red/purple; do not infer an alphabetical-order guarantee from the comment.

Manu cell 9 encodes `trait_mat <- model.matrix(~ Subtype, metadata)[, -1]` and explicitly assigns sample row names. With selected preprocessing levels, its columns are SubtypeERpos, SubtypeTNBC and SubtypeHER2pos; Normal rows have all three zeros. Correlation to each indicator is across all samples, not a separately restricted subtype-versus-Normal sample comparison. Batch and patient terms are not included in this association step.

`mod_trait_cor <- cor(MEs, trait_mat, use = "pairwise.complete.obs")`; `corPvalueStudent(mod_trait_cor, nSamples = nrow(metadata))`; `apply(mod_trait_pval, 2, p.adjust, method = "BH")`. BH is applied separately across modules within each trait column, not across all module/trait tests jointly. The saved matrix includes grey among 20 rows. The source sets no explicit correlation `method` here or in eigengene plots, and no explicit robust/bicor method. The setup's unqualified `cor` binding and package defaults control behavior; printed “Pearson” text in cell 16 is a label, not an extra supplied method argument.

Cell 9's console “top associations” filter combines `any(abs(r) >= 0.4)` and `any(FDR < 0.05)` separately, which can be satisfied by different traits. Cell 112 instead pairs each trait's correlation/FDR condition, and writes a different summary-column schema to the same filenames. These are reporting variants; the substantive cell 10 selection uses paired **absolute r ≥ 0.50 and FDR < 0.05** per trait. It strips `ME` and explicitly discards turquoise. Cell 93 adds a parallel raw-p < 0.05 variant with the same ≥ 0.50 correlation cutoff; cell 107 reports a conjunction of correlation, raw p and FDR criteria. None licenses silently changing the earlier association branch.

## Hub definitions, alignment and panel variants

- Cell 10 exports **all genes** from selected module colors, not a gene-level significance-filtered hub panel. It reuses `moduleColors` if already present; it checks length only, so stale same-length state is not rejected. `geneMod` assigns `colnames(expr)` to colors positionally.
- Cell 15 calls `signedKME(expr, MEs, outputColumnName = "kME")`, then strips `kME` from its column names and applies `labels2colors(me_labels)`. It does not simply preserve color-named eigengene suffixes. Its identity remains provisional as described in “Provisional kME identity: observations versus explanation” below; the project decision is to preserve cell 15 as written, not correct the mapping in the faithful baseline. Dimensions alone do not validate it. kME table rows and `IMC$kWithin` are consumed positionally in cell 16, without explicit gene-ID matching. Assigned-module kME columns are matched by name using `cbind`/`match`; the NA guard does not establish semantic correctness of that color remapping.
- No executable per-gene gene-significance (GS) calculation, GS p-value cutoff, absolute-kME hub cutoff or kME p-value threshold appears. Quantiles in cell 15 are descriptive, not hub eligibility cutoffs. Internal blockwise kME retention defaults are separate from downstream hub selection.
- Cell 17 ranks descending `kWithin` and takes `head(..., 10)` per non-grey/gold module. Cells 21–22 rank all subtype-exported nodes descending `kWithin` and take `[1:20, ]` (no explicit tie-breaker or short-list guard).
- Cell 26's hub-selection prefix ranks descending `kWithin`, takes `head(..., 50)` per non-grey/gold module and deduplicates indices. Its subsequent edge-list code is excluded from this extraction.
- Cell 28 hard-codes TNBC = greenyellow/midnightblue; HER2 = black/yellow/midnightblue/magenta/blue; ERpos = brown/black. It uses `head(..., k)` with `k = 50`, deduplicates indices and creates overlapping subtype hub sets. No separate kME/GS requirement is imposed.
- Cell 47 is a **different final panel**: exactly seven explicitly assigned module/subtype pairs, 50 descending-kWithin genes per pair, then `unique(final_hub_genes)`. It assigns black only to ERpos and midnightblue only to TNBC, with HER2pos restricted to yellow/magenta/blue. Its `[1:50]` indexing lacks a guard for modules with fewer than 50 genes; the saved selected modules are all larger. It labels genes by manually assigned subtype, not an executable rule choosing a winning trait. Ranking ties have no explicit ID tie-breaker.

Grey is present in historical module/ME tables (numeric 0 → grey in the February mapping). Core hub loops exclude **grey and gold**; grey60 is a separate named module and is not removed by these checks. Module/trait testing does not explicitly exclude grey. The cell 10/93 comments call turquoise a “catch-all” and the code drops it; this is a narrative designation, not a demonstrated unassigned status. Turquoise is a 7,346-gene module with an eigengene and strong saved association. Do not replace its exclusion with a grey exclusion silently. Gold is excluded by hub code but absent from the saved module table.

## Direct packages by stage and omitted defaults

| Stage | Direct package use in source |
| --- | --- |
| Thresholding/network/ME/association/connectivity/kME | WGCNA; base R and stats for model matrices, p.adjust, tables and graphics. |
| Threshold plots | ggplot2, gridExtra (cell 3). |
| Module/trait heatmaps | pheatmap (cell 9; variants 111 and February 6); base stats heatmap in other cells. |
| kME/connectivity diagnostic scatter | scales via `scales::alpha` (cell 16); ggplot2 for cell 18 boxplot. |
| CSV/RData serialization | Base R and utils. |
| Original installation support | BiocManager; the setup requests WGCNA plus impute, preprocessCore, GO.db and AnnotationDbi. Those auxiliary packages are setup/dependency requirements rather than explicit analytical calls in the extracted blocks. |

DESeq2, limma and dplyr belong to preceding preprocessing; do not infer new direct WGCNA requirements merely from their continued presence in the notebook session. Installation commands in quoted source are historical code, not authorization to install anything now. WGCNA and the plotting/dependency closure were installed and locked separately, as recorded below; this implementation does not install or change packages.

All arguments absent from the verbatim calls remain package defaults, including soft-threshold correlation/block-size/fit-cutoff settings; `blockwiseModules` settings above; `orderMEs` ordering options; `signedKME` correlation/missing-value options; `intramodularConnectivity` scaling/unassigned-color options; and correlation methods. Do not fill omissions with contemporary remembered defaults and label them historical. Historical WGCNA/dependency versions are not recovered by the R/Bioconductor release logs; their effective defaults and full reproducibility remain unresolved.

## Historical checkpoints and written artifacts

These checkpoints are from saved notebook outputs only. No WGCNA checkpoint was reproduced in this task.

| Source | Historical evidence |
| --- | --- |
| Manu 3 | 25,750 genes; thresholding uses calculated block size 1737; 40 × 7 `sft_df`; power 6 SFT.R.sq 0.81207164, mean.k 1086.329. |
| Manu 5–6 | Power 6 in code; single TOM block saved as `TOM-block.1.RData`; 20 distinct colors **including grey** (19 non-grey modules); `MEs` 279 × 20. |
| Manu 9 | Module/trait correlation matrix 20 × 3. |
| Manu 10 | Significant ME counts ERpos 2, TNBC 2, HER2pos 6; after turquoise removal HER2pos has 5 colors. Extracted genes: 3,781 ERpos, 321 TNBC, 9,074 HER2pos. |
| Manu 13, 15–16 | Adjacency 25,750 × 25,750; kME table 25,750 × 20; masterNodes 25,750 rows. Printed kME range -0.9165947 to 0.9473426 and r(kME,kWithin) 0.445 are **provisional saved summaries, not validated kME-identity checkpoints**. |
| Manu 26 | 920 global top-50-per-core-module hubs reported (not 350). |
| Manu 28 | TNBC 100, HER2 250, ERpos 100 hubs, with overlapping selected modules. |
| Manu 46 (input inventory only, no ML analyzed) | All selected-module gene lists are labelled “hub genes”: 321/9,074/3,781; unique union 12,619 and overlaps TRUE. These are not the later final panel. |
| Manu 47 | Saved count **350**; 100 TNBC, 150 HER2pos, 100 ERpos from seven module/subtype pairs. The “should be 350” comment alone is not evidence; the saved printed count supports the report. |
| Manu 93, 107 | Alternative raw-p and FDR lists have 3,781/321/9,074 selected genes after dropping turquoise; QC counts 2/2/6 modules before removal. |
| Manu 111–112 | Saved eigengene correlation 20 × 20, range [-0.84, 1.00]; repeated module/trait matrix 20 × 3. |
| Manu 119 | Partial saved report has numeric labels 0–19 and matching printed sizes, then errors at the gene-assignment preview; this branch did not complete. |

Saved Manu cell 6 module sizes:

| Color | Size | Color | Size |
| --- | ---: | --- | ---: |
| black | 470 | blue | 6198 |
| brown | 3311 | cyan | 100 |
| green | 1013 | greenyellow | 234 |
| grey | 2876 | grey60 | 49 |
| lightcyan | 53 | lightgreen | 38 |
| lightyellow | 33 | magenta | 400 |
| midnightblue | 87 | pink | 452 |
| purple | 323 | red | 535 |
| salmon | 140 | tan | 173 |
| turquoise | 7346 | yellow | 1919 |

Artifact names explicitly written by the in-scope code: `soft_thresholding_results.csv`, `scale_free_topology.png`, `TOM-block.1.RData` (saved log), `WGCNA_results_power6.RData` (formatted filename), `module_summary.csv`, `module_dendrogram_block%02d.png`, `module_eigengene_heatmap.png`, `module_trait_correlations.csv`, `module_trait_pvalues.csv`, `module_trait_FDR.csv`, `module_trait_summary.csv`, `module_trait_heatmap.png`, `<Trait>_FDR_genes.csv`, `adjacency_degree_dist.png`, `degree_stats.RData`, `kME_table.RData`, `kME_vs_kWithin.png`, `masterNodes.csv`, `top_hub_genes_by_module.csv`, `module_counts.csv`, `<Trait>_nodes.csv`, `<Trait>_top20_hub_genes.csv`, `hubNodes.csv` (selection prefix), `tnbcHubNodes.csv`, `her2HubNodes.csv`, `erposHubNodes.csv`, `final_hub_genes_info.csv`, `final_hub_genes.csv`. Variants also write rawP gene CSVs, `eigengene_correlation.csv`, `module_dendrogram_fixed.png`, `module_eigengene_heatmap_high_res.png` and `module_trait_heatmap_high_res.png`. A write call records intent, not proof that a repository copy is complete/current; later cells overwrite several names. No generated files are created by this documentation task.

## Contradictions, variant differences and project decisions

1. **Network type omission:** the selected path preserves the missing `networkType`, while retaining signed threshold exploration and signed hub adjacency. Historical effective defaults remain unknown; changing the omission would be a separate methodological correction.
2. **Label state contradiction:** Manu cell 5 sets numericLabels FALSE and saves color labels; cell 119 saves numeric labels before an error. February uses numericLabels TRUE. The selected path excludes those alternate states and preserves cell 15, but its kME identity remains an unresolved limitation rather than a validated mapping.
3. **Selection branches:** Manu cells 9/10 are selected. Cells 112/93 and February raw-p variants remain excluded comparison evidence; their common filenames and similar saved sets do not justify combining them.
4. **Hub definition:** cell 47's manual seven-pair panel is selected. Top-10/top-20/global-top-50/overlapping-subtype exports remain optional historical variants. Selection is not evidence that the 350 panel is scientifically validated or uniformly assigned by association strength/sign.
5. **Missing QC/provenance:** no explicit sample outlier rule or patient handling, no proven history for goodSamples/goodGenes or color state, no explicit gene-ID joins for connectivity/kME, and no historical package lockfile. Saved logs/dimensions do not resolve these omissions.
6. **Turquoise/grey claims:** preserve the original turquoise exclusion despite its unsupported “catch-all” narrative; grey is counted among “20 modules” and tested in association, while grey/gold are excluded by core hub loops. Keep these distinctions in baseline claims.

February differences are substantive: `data`/`category` rather than `expr`/`Subtype`; numericLabels TRUE; no active WGCNA thread/cor override in cell 2 (the suggested overrides are commented); `MEs <- net$MEs` without `orderMEs`; `~ category` traits; raw p-values only in cell 6, then **strict abs(r) > 0.5** and p < 0.05 in cell 11, rather than Manu's ≥ 0.50 and BH-FDR rule. February cell 13 drops turquoise, cell 14 selects all genes in those modules, and cell 18 uses numeric-ME-derived kME column names as if they were color-named, without Manu cell 15's remapping; this is a missing mapping step, not permission to borrow the Manu code. The comment suggesting adjacency may require transposition is not an executed step; the adjacency call already consumes samples × genes. No GS calculation is executed: the optional geneCorr example is commented.

February cell 3 unconditionally executes `TOM <- 1 - TOM` after loading/converting the saved TOM, even though its comments describe a conditional diagonal-based diagnosis. No saved diagonal output establishes that this complement was necessary. Manu's hub workflow recomputes adjacency and does not execute that conversion. February cell 5's base dendrogram followed by ggsave with no explicit plot is also not the same saving procedure as Manu's PNG device helpers. Do not import these variants into a faithful Manu route.

Strong dataset/subtype confounding, repeated patients and fragile cross-dataset overlap remain scientific limitations. Pairwise-complete correlation, BH adjustment, topology-fit plots and historical checkpoint agreement do not establish independent observations, biological preservation, validated subtype specificity or publication-ready results. The project has now chosen a single faithful path; repository access is not a blocker. Historical defaults/session order, kME identity and comparator provenance remain unresolved. Preserve those limitations during any separately authorized implementation instead of silently repairing the baseline.

## Saved errors and partial execution evidence

These are notebook JSON `output_type = "error"` entries, not errors produced in this task. Earlier output within a cell does not establish completion of its remaining statements.

| Source | Saved error and consequence |
| --- | --- |
| Manu cell 4 | `error in evaluating the argument 'x' in selecting a method for function 'head': object 'sft_df' not found`. The head/summary reporting did not complete, despite cell 3 defining `sft_df` in its current source. This is evidence of unresolved session order/state. |
| Manu cell 8 | `Error in par(op): invalid value specified for graphical parameter "pin"`. Saved plots appear around this error, but the cell is not evidence of a fully completed graphical branch. Cell 8 remains outside the selected path. |
| Manu cell 119 | `error in evaluating the argument 'x' in selecting a method for function 'head': arguments imply differing number of rows: 0, 25750`. Numeric labels/sizes were printed first, but the `data.frame(Gene=colnames(expr), Module=net$colors)` preview failed. The error establishes a length mismatch at that point, not its cause; do not claim this reporting branch completed. |
| February cell 10 | `error in evaluating the argument 'x' in selecting a method for function 'head': object 'label_color_mapping' not found`. Earlier ME/label/assignment previews exist; the named mapping preview failed and the following `head(moduleTraitResults)` was not reached in this saved execution. The earlier mapping object is named `mapping_df`. |
| February cell 18 | `Error in adjacency(data, power = softPower, type = "signed"): could not find function "adjacency"`. The failure is at the initial adjacency call, before that cell's `library(WGCNA)`; its later kME/connectivity/masterNodes/CSV code cannot be described as completed based on this execution. |

## Provisional kME identity: observations versus explanation

Observed Manu cell 15 code takes `signedKME` output column suffixes, calls `labels2colors(me_labels)`, and renames columns. Cell 16 then retrieves assigned-module kME by the renamed columns. The source does not persist an explicit original-ME-to-renamed-column identity table. A same-size table and nonmissing-column assertion cannot establish the biological identity of each renamed column.

**Suspected explanation, not independently verified:** if the suffixes already identify color-named eigengenes in the selected cell 5/6 branch, converting those labels through `labels2colors` could reassign color identities rather than preserve them. Numeric-label session state could lead to a different mapping. Historical WGCNA behavior and the actual session state have not been recovered; this documentation does not assert that this mechanism caused the saved values.

Observed saved values include assigned kME -0.9165947 to 0.9473426 and printed r(kME,kWithin) 0.445 in cell 16. Cell 22's top-kWithin TNBC rows include UGT8 kME 0.19871761, ROPN1 0.01204484 and ROPN1B -0.01458546. **Low kME for genes selected only by kWithin does not prove mislabelling.** Cell 15's quantiles are calculated over every gene row for each kME column, not just genes assigned to that module, so their distribution is not a within-module identity check. Treat the cell 15/16 kME summaries and derived kME values in historical exports as **provisional saved observations, not validated checkpoints**. Preserve the code in the faithful baseline; any mapping correction belongs to a separate analysis.

Verified Manu cell 22 saved contrast: all 20 displayed HER2pos top hubs are blue, with kME values **0.8971585–0.9473426**; all 20 displayed ERpos top hubs are brown, with kME values **0.8061466–0.8995280**. For example, GPR22 (blue) has kWithin 1109.7267 and kME 0.9434168, while WASH7P (brown) has kWithin 447.4856 and kME 0.8995280. These high saved blue/brown values contrast with the low values in some top-kWithin TNBC rows above. They are observations from optional historical exports, **not evidence that the kME columns are correctly labelled**; their kME identity remains provisional. Cell 22 remains outside the selected path.

## Signed associations behind the manually assigned panel

The following are saved Manu cell 9 correlations (also shown in cell 112), rounded here to six decimals. They are associations of MEs with subtype indicators, not per-gene significance or a rule assigning a winning subtype.

| Cell 47 module | Manual subtype | r with ERpos | r with TNBC | r with HER2pos |
| --- | --- | ---: | ---: | ---: |
| greenyellow | TNBC | -0.463188 | 0.775561 | -0.313354 |
| midnightblue | TNBC | -0.035732 | 0.517413 | -0.703946 |
| yellow | HER2pos | 0.125964 | 0.007878 | -0.583134 |
| magenta | HER2pos | -0.454667 | -0.010641 | 0.530236 |
| blue | HER2pos | -0.390869 | -0.236153 | 0.806716 |
| black | ERpos | 0.857995 | -0.206889 | -0.589757 |
| brown | ERpos | 0.592778 | 0.228332 | -0.437470 |

In particular, yellow has a **negative** HER2pos association, and midnightblue has a **stronger absolute association with HER2pos** (0.703946) than TNBC (0.517413), yet cell 47 assigns it exclusively to TNBC. Black also belongs to the saved significant HER2pos set but is manually assigned only to ERpos. The panel therefore cannot be described as a uniformly positive, strongest-association or independently validated subtype-specific panel.

## Saved raw-p versus FDR module sets

Read-only comparison used February cell 12's saved numeric ME sets, cell 5's saved numeric-to-color mapping, cell 13's saved post-turquoise colors, and Manu cell 10's saved FDR colors. **The saved sets agree**, notwithstanding different executable rules (February strict abs(r) > 0.5/raw p < 0.05 versus Manu abs(r) ≥ 0.50/BH-FDR < 0.05).

| Trait | February saved pre-removal set (consistent with Manu counts/associations) | Both saved sets after removal |
| --- | --- | --- |
| ERpos | black, brown | black, brown |
| TNBC | greenyellow, midnightblue | greenyellow, midnightblue |
| HER2pos | black, yellow, midnightblue, turquoise, magenta, blue | black, yellow, midnightblue, magenta, blue |

February cell 12 reports ER ME3/ME7, TNBC ME11/ME15 and HER2 ME7/ME4/ME15/ME1/ME9/ME2; mapping ME1 to turquoise explains its removal. Manu cell 10 reports significant counts 2/2/6 and the same final colors. This is equality of the saved selection outputs, not proof of general equivalence of the rules, identical historical runs or completed execution of other February branches.

## Tracked historical Results/WGCNA_Modules inventory

`git ls-files Results/WGCNA_Modules` identifies the seven files below. CSVs were read with Python's CSV reader; the RData file was inventoried by size/hash only, not loaded or treated as a freshly generated network. Row counts exclude headers; blank CSV index columns are preserved. These are tracked historical artifacts, not new reproduction outputs.

| Tracked file (under Results/WGCNA_Modules/) | Bytes | Read-only schema/checkpoint |
| --- | ---: | --- |
| `WGCNA_results_full.RData` | 206,940 | RData artifact; contents not inspected in this inventory. |
| `gene_module_assignments.csv` | 667,043 | 25,750 rows; columns: index (blank header), `Gene`, `Module` |
| `module_summary.csv` | 387 | 20 rows; columns: index (blank header), `moduleColors`, `Freq` |
| `module_trait_correlations.csv` | 1,305 | 20 rows; columns: index (blank header), `categoryER+`, `categoryHER2+`, `categoryTNBC` |
| `module_trait_pvalues.csv` | 1,371 | 20 rows; columns: index (blank header), `categoryER+`, `categoryHER2+`, `categoryTNBC` |
| `module_trait_summary.csv` | 2,690 | 20 rows; columns: index (blank header), `Module`, `TNBC_Correlation`, `TNBC_P.value`, `HER2_Correlation`, `HER2_P.value`, `ER_Correlation`, `ER_P.value` |
| `soft_thresholding_results.csv` | 4,579 | 40 rows; columns: index (blank header), `Power`, `SFT.R.sq`, `slope`, `truncated.R.sq`, `mean.k.`, `median.k.`, `max.k.` |

`gene_module_assignments.csv` contains 25,750 gene/module records and is a **potential full historical gene-assignment comparator**, beyond printed previews. Its source-run provenance remains unresolved; the inventory does not establish that it arose from the selected Manu path or license comparing it as definitive ground truth. The numeric ME labels, category column names, raw-p summary schema and `WGCNA_results_full.RData` filename resemble February evidence, but that resemblance is not proof of origin. No full new-versus-historical network/assignment comparison was performed here. No FDR matrix or 350-gene panel CSV is tracked in this directory.

Read-only verification found that `module_summary.csv` frequencies and the module counts independently tallied from `gene_module_assignments.csv` **exactly reproduce all 20 module sizes saved in Manu cell 6**, including grey = 2,876, blue = 6,198, brown = 3,311 and turquoise = 7,346; both totals are 25,750 genes. This establishes **module-size consistency only**, not gene-by-gene agreement with a newly reproduced network, correct kME identity or confirmed source-run provenance. Source-run provenance remains unresolved.

Inventory SHA-256 values (current file identity, not recovered source-run provenance):

| File | SHA-256 |
| --- | --- |
| `WGCNA_results_full.RData` | `b6d5a73659e5f1efe5cc0d36a9cb8b1aed243aca3afd3ec5bfccaa9307f76a92` |
| `gene_module_assignments.csv` | `f69f7c66a2680a3cbadb95140ddc763c4ac13a2414517743ed949e8bf90ea226` |
| `module_summary.csv` | `09067c9b59d70b17415270d466c9cf4934c0c6311aa0cd1350fff99ade43151e` |
| `module_trait_correlations.csv` | `dca7f171908e7f0ef123efae5851e981100ef24f1266558d4416b56f0b3bc9de` |
| `module_trait_pvalues.csv` | `d65a4e9b8e7edc869909db24a1f4e4883aa21fd90fb72e9579fc8ea8423b3439` |
| `module_trait_summary.csv` | `a7e8c56dde5e05fc117cc1ed4a3977cada67ba5558896dbfc2d0694bb8b932f3` |
| `soft_thresholding_results.csv` | `14d1448e59764fedb1fcfa998059fc16c176624b9e86c4ecc6f0c6f8d7f13e51` |

## Installed and locked reproduction dependencies (2026-10-14)

Dependency installation was authorized separately from WGCNA execution. Preflight confirmed branch `analysis/initial-review`, HEAD `8fbb9fa` (`8fbb9fa65c8204df0505c1a4edfbb8325b25c7b4`) and a clean working tree. Activated environment: R **4.5.2**, renv **1.3.1**, Bioconductor **3.21**. No WGCNA analysis or network construction was implemented or run. The following are **new reproduction versions**, not recovered historical versions.

The complete approved list was reconstructed from Claude's table with explicit overrides for survival, cluster, nnet, rpart and foreign. All 45 exact source versions were downloaded for read-only DESCRIPTION verification, including archived CRAN versions where needed. Combined with the existing 68 locked versions, the required Depends/Imports/LinkingTo closure was exactly **113 non-base packages**; **213 versioned constraints** passed, with no conflicts or missing requirements. Suggests and broad updates were excluded. Bioconductor additions were resolved through the pinned 3.21 repository and their exact versions verified before installation and in the snapshot. GO.db and AnnotationDbi were not added.

All **45 additions installed successfully into the project-local renv library**, using its normal user cache. renv reported 310 seconds for installation; 25 additions required compilation. No system packages or existing locked packages were changed. The complete approved/installed additions are:

| Package | Version | Source |
| --- | --- | --- |
| `backports` | 1.5.1 | CRAN |
| `base64enc` | 0.1-6 | CRAN |
| `bslib` | 0.12.0 | CRAN |
| `cachem` | 1.1.0 | CRAN |
| `checkmate` | 2.3.4 | CRAN |
| `cluster` | 2.1.8.2 | CRAN |
| `colorspace` | 2.1-4 | CRAN |
| `data.table` | 1.18.6.1 | CRAN |
| `digest` | 0.6.39 | CRAN |
| `doParallel` | 1.0.17 | CRAN |
| `dynamicTreeCut` | 1.63-1 | CRAN |
| `evaluate` | 1.0.5 | CRAN |
| `fastcluster` | 1.3.0 | CRAN |
| `fastmap` | 1.2.0 | CRAN |
| `fontawesome` | 0.5.3 | CRAN |
| `foreach` | 1.5.2 | CRAN |
| `foreign` | 0.8-91 | CRAN |
| `Formula` | 1.2-6 | CRAN |
| `fs` | 2.1.0 | CRAN |
| `gridExtra` | 2.3.1 | CRAN |
| `highr` | 0.12 | CRAN |
| `Hmisc` | 5.3-0 | CRAN |
| `htmlTable` | 2.5.0 | CRAN |
| `htmltools` | 0.5.9 | CRAN |
| `htmlwidgets` | 1.6.4 | CRAN |
| `impute` | 1.82.0 | Bioconductor 3.21 |
| `iterators` | 1.0.14 | CRAN |
| `jquerylib` | 0.1.4 | CRAN |
| `knitr` | 1.52 | CRAN |
| `memoise` | 2.0.1 | CRAN |
| `nnet` | 7.3-20 | CRAN |
| `pheatmap` | 1.0.13 | CRAN |
| `preprocessCore` | 1.70.0 | Bioconductor 3.21 |
| `rappdirs` | 0.3.4 | CRAN |
| `rmarkdown` | 2.32 | CRAN |
| `rpart` | 4.1.24 | CRAN |
| `rstudioapi` | 0.19.0 | CRAN |
| `sass` | 0.4.10 | CRAN |
| `stringi` | 1.8.9 | CRAN |
| `stringr` | 1.6.0 | CRAN |
| `survival` | 3.8-6 | CRAN |
| `tinytex` | 0.61 | CRAN |
| `WGCNA` | 1.74 | CRAN |
| `xfun` | 0.61 | CRAN |
| `yaml` | 2.3.12 | CRAN |

### Loading, warnings and installed defaults

Five separate fresh activated Rscript processes successfully loaded WGCNA, gridExtra, pheatmap, impute and preprocessCore, with **zero captured warnings** in each. A further fresh process loaded DESeq2 → limma → WGCNA, followed by gridExtra/pheatmap, and captured **one warning**: the previously reviewed SummarizedExperiment import replacement involving S4Arrays/DelayedArray. Full captured text is retained in the diagnostics RDS; no new load warnings were captured. Function inspection and session setup did not construct a network.

After `cor <- WGCNA::cor`, function identity and namespace environment `WGCNA` were verified. Full installed `formals()` for blockwiseModules, pickSoftThreshold, adjacency, signedKME, intramodularConnectivity, orderMEs, cor and enableWGCNAThreads were saved in `installed-function-defaults.rds` and `.txt`. Representative **WGCNA 1.74 reproduction defaults**, not historical defaults:

| Function/argument | Installed default |
| --- | --- |
| blockwiseModules: networkType / TOMType | `"unsigned"` / `"signed"` |
| blockwiseModules: deepSplit / detectCutHeight | 2 / 0.995 |
| blockwiseModules: pamStage / pamRespectsDendro | TRUE / TRUE |
| blockwiseModules: TOMDenom / corType | `"min"` / `"pearson"` |
| blockwiseModules: minKMEtoStay / minCoreKME | 0.3 / 0.5 |
| blockwiseModules: impute / nThreads | TRUE / 0 |
| cor: use | `"all.obs"` |
| cor: method formal | `c("pearson", "kendall", "spearman")` |

The selected baseline still preserves source omissions and cell 15 as written. Recording installed defaults does not correct the analytical source or recover its actual historical session. Symbolic/default expressions are preserved in the full formals records; network-specific runtime behavior has not been exercised.

### Thread and numerical-library configuration

`enableWGCNAThreads()` without an explicit argument reported **7 working processes**; `WGCNAnThreads()` returned **7**. `parallel::detectCores()` reported **8**, including 8 for `logical = FALSE`. In that fresh session `ALLOW_WGCNA_THREADS` was `"7"`; OMP_NUM_THREADS, OMP_THREAD_LIMIT, OPENBLAS_NUM_THREADS, GOTO_NUM_THREADS, MKL_NUM_THREADS, BLIS_NUM_THREADS, VECLIB_MAXIMUM_THREADS and RCPP_PARALLEL_NUM_THREADS were unset. These are observed session settings, not a measured BLAS thread count or proof of network parallel performance.

BLAS: `/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.1`; LAPACK: `/usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.12.1`. Contrast options were `contr.treatment` / `contr.poly`. Full configuration and session information are retained in the local diagnostics.

### Targeted snapshot safeguards and evidence

An explicit snapshot used exactly these roots: renv, BiocManager, BiocVersion, DESeq2, limma, dplyr, ggplot2, scales, WGCNA, gridExtra and pheatmap. It was first written to a temporary lockfile. Acceptance checks required exactly **113 packages**, identical complete records for **all original 68 packages**, exactly the **45 approved additions** at their verified versions/sources, and unchanged R/repository/Bioconductor configuration and `renv/settings.json`. All checks passed before the verified preview was copied to `renv.lock`.

Final checks confirmed exact equality of the project-library package set and lockfile package set, matching versions for all 113 packages, unchanged original records, and the exact required closure. `renv::status()` reported the 45 additions as installed/recorded but **unused under implicit source discovery**, because no WGCNA implementation script exists yet; this is distinguished from a missing package or version mismatch. The implicit snapshot setting was not changed, and excluded notebook branches were not used as snapshot roots.

Diagnostics are preserved under the Git-ignored directory **`renv/local/wgcna-dependency-install-20261014/`**, separate from analysis outputs: approved-plan.csv (complete versions/source URLs), source DESCRIPTION records in approved-plan.rds, metadata logs, installation.log, five individual load logs and warning RDS files, load-session.log and warnings-session.rds, installed-function-defaults records, thread-configuration records, sessionInfo.txt, snapshot-preview.log, the accepted preview and original lockfiles, and final-consistency.log. Temporary verification initially encountered sandbox DNS/cache restrictions and a malformed Bioconductor URL in the verifier; those pre-install failures were corrected before installation began. Neither was an unavailable approved version or an installation failure; their logs are retained. The actual installation succeeded without repair or retry.

Successful compilation/loading and dependency consistency do not establish WGCNA runtime success, scientific validation or historical reproducibility. **WGCNA execution remains pending a resource assessment**: this installation did not test the memory requirements of a single 25,750-gene block or full adjacency, BLAS/network performance, cross-machine behavior, or the provisional kME identity problem. Original inputs, notebooks, existing baseline outputs and renv settings remain unchanged.

## Verbatim source appendix

The blocks below are documentary extracts and must not be executed as a concatenated script. Repeated functions/object names denote variants, not a combined workflow. Full cells include historical installation lines where present; none was run here.

### Manu cell 1 — setup excerpt (WGCNA attachment, threads and cor binding)

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 1.

```r
library(WGCNA)          # 1. attach WGCNA *last*
enableWGCNAThreads()    # 2. optional speed-up
cor <- WGCNA::cor       # 3. guarantee the fast correlation is used
```

### Manu cell 3 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 3.

```r
# Choose soft-thresholding powers to evaluate
powers <- c(1:20, seq(12,50,2))
sft <- pickSoftThreshold(expr, powerVector = powers, networkType = "signed", verbose = 5)
sft_df <- sft$fitIndices
write.csv(sft_df, "soft_thresholding_results.csv")

# High-quality plots for scale-free topology and mean connectivity
library(ggplot2)
library(gridExtra)

# Plot for scale-free topology fit
a1 <- ggplot(sft_df, aes(x = Power, y = SFT.R.sq, label = Power)) +
  geom_point(size = 3, color = 'blue') +
  geom_text(nudge_y = 0.05, size = 3) +
  geom_hline(yintercept = 0.8, color = 'red') +
  labs(
    x = 'Soft Threshold (Power)',
    y = 'Scale-Free Topology Fit Index',
    title = 'Scale-Free Topology'
  ) +
  theme_classic()

# Plot for mean connectivity
a2 <- ggplot(sft_df, aes(x = Power, y = mean.k., label = Power)) +
  geom_point(size = 3, color = 'red') +
  geom_text(nudge_y = 50, size = 3) +
  labs(
    x = 'Soft Threshold (Power)',
    y = 'Mean Connectivity',
    title = 'Mean Connectivity'
  ) +
  theme_classic()

# Save both plots side by side
ggsave("scale_free_topology.png", grid.arrange(a1, a2, ncol = 2), width = 10, height = 5)

# ---- Reporting (copy and paste output below for LLM to help interpret) ----
cat("Shape:\n"); print(dim(sft_df))
cat("\nHead:\n"); print(head(sft_df))
cat("\nSummary:\n"); print(summary(sft_df))
```

### Manu cell 5 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 5.

```r
# ─── Chunk 9: Module Detection ────────────────────────────────────────────────
# Purpose: Construct a weighted gene co-expression network and detect gene modules.

softPower <- 6

net <- blockwiseModules(
  expr,
  power         = softPower,
  maxBlockSize  = 26000,
  TOMType       = "signed",
  minModuleSize = 30,
  reassignThreshold = 0,
  mergeCutHeight    = 0.25,
  numericLabels     = FALSE,
  randomSeed        = 1234,
  saveTOMs          = TRUE,
  saveTOMFileBase   = "TOM",
  verbose           = 3
)

# --- Reporting & Output: ---
cat("Network object type:\n"); print(class(net))
cat("\nNames in network object:\n"); print(names(net))
cat("\nModule labels (first 20):\n"); print(head(net$colors, 20))
cat("\nNumber of modules detected:\n"); print(length(unique(net$colors)))
cat("\nModule sizes:\n"); print(table(net$colors))
cat("\nFirst 20 gene assignments:\n"); print(head(data.frame(Gene=colnames(expr), Module=net$colors), 20))
```

### Manu cell 6 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 6.

```r
## ───────────────────────── Chunk 10 · Module metadata & eigengenes ──────────
# 0. Quick sanity: how many modules and their sizes
module_summary <- as.data.frame(table(ModuleColor = net$colors))
names(module_summary)[2] <- "Size"

# 1. Order eigengenes (puts grey last, colours alphabetical)
MEs <- orderMEs(net$MEs)

# 2. Persist results for downstream use / reproducibility
save(net, module_summary, MEs,
     file = sprintf("WGCNA_results_power%d.RData", softPower))

write.csv(module_summary, "module_summary.csv", row.names = FALSE)

# 3. Console reporting for LLM / log
cat("\n=== Module summary ===\n")
print(module_summary)

cat("\nEigengene matrix dimensions:\n")
print(dim(MEs))

cat("\nHead of eigengene matrix (first 6 modules):\n")
print(head(MEs[, 1:min(6, ncol(MEs))]))
```

### Manu cell 8 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 8.

```r
# ─────────────────── Chunk 11 · Dendrogram & Eigengene heatmap ──────────────
suppressPackageStartupMessages(library(WGCNA))

# helper that:  (a) shows on-screen, (b) also saves high-res PNG --------------
plot_and_save <- function(file, expr) {
  ## A. show immediately on the current graphics device
  expr()                                   # run the plotting expression once

  ## B. save a 300-dpi PNG copy
  png(file, width = 3600, height = 2400, res = 300)
  expr()                                   # run it again into the PNG device
  dev.off()
}

# 1. dendrogram(s) ------------------------------------------------------------
for (b in seq_along(net$dendrograms)) {
  plot_and_save(
    file = sprintf("module_dendrogram_block%02d.png", b),
    expr = function() {
      plotDendroAndColors(
        dendro        = net$dendrograms[[b]],
        colors        = net$colors[ net$blockGenes[[b]] ],
        groupLabels   = "Dynamic Tree Cut",
        dendroLabels  = FALSE,
        hang          = 0.03,
        addGuide      = TRUE,
        guideHang     = 0.05,
        main          = sprintf("Block %02d", b)
      )
    }
  )
}

# 2. eigengene-correlation heatmap -------------------------------------------
plot_and_save(
  file = "module_eigengene_heatmap.png",
  expr = function() {
    heatmap(
      as.matrix(cor(orderMEs(net$MEs), use = "p")),
      symm = TRUE,
      main = "Module Eigengene Correlation Heatmap"
    )
  }
)

cat("\nRendered to screen *and* saved PNGs for",
    length(net$dendrograms), "dendrogram(s) + heatmap.\n")
```

### Manu cell 9 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 9.

```r
install.packages('pheatmap')
library(pheatmap)
## ───────────────────────── Chunk 12 · Module–trait correlation ─────────────
#  Assumes:  `MEs` (module eigengenes) and `metadata` already in workspace
#  Output:   correlation / p-value / FDR matrices, tidy summary table,
#            pretty heat-map displayed + saved PNG

suppressPackageStartupMessages({
  library(WGCNA)      # corPvalueStudent
  library(pheatmap)   # pretty heat-map with on-tile numbers
})

# 0.  Belt-and-braces alignment check ─────────────────────────────────────────
stopifnot(identical(rownames(MEs), rownames(metadata)))   # samples in identical order

# 1.  Build one-hot matrix for Subtype (Normal = reference) ───────────────────
trait_mat <- model.matrix(~ Subtype, metadata)[, -1]      # drop intercept
rownames(trait_mat) <- rownames(metadata)

# 2.  Correlate module eigengenes with traits + stats ─────────────────────────
mod_trait_cor  <- cor(MEs, trait_mat, use = "pairwise.complete.obs")
mod_trait_pval <- corPvalueStudent(mod_trait_cor, nSamples = nrow(metadata))
mod_trait_fdr  <- apply(mod_trait_pval, 2, p.adjust, method = "BH")   # BH FDR

# 3.  Save full matrices ──────────────────────────────────────────────────────
write.csv(mod_trait_cor,  "module_trait_correlations.csv")
write.csv(mod_trait_pval, "module_trait_pvalues.csv")
write.csv(mod_trait_fdr,  "module_trait_FDR.csv")

# 4.  Tidy summary table (auto-grows with number of traits) ───────────────────
trait_names <- colnames(trait_mat)
moduleTraitResults <- data.frame(Module = rownames(mod_trait_cor))

for (tn in trait_names) {
  moduleTraitResults[[paste0(tn, "_Corr")]] <- mod_trait_cor[, tn]
  moduleTraitResults[[paste0(tn, "_FDR") ]] <- mod_trait_fdr [, tn]
}

write.csv(moduleTraitResults, "module_trait_summary.csv", row.names = FALSE)

# 5.  Console breadcrumbs ─────────────────────────────────────────────────────
cat("\n=== Top module–trait associations (|r| ≥ 0.4, FDR < 0.05) ===\n")
print(
  subset(moduleTraitResults,
         apply(moduleTraitResults[ , grepl("_Corr$", names(moduleTraitResults))], 1,
               function(r) any(abs(r) >= 0.4)) &
         apply(moduleTraitResults[ , grepl("_FDR$",  names(moduleTraitResults))], 1,
               function(f) any(f < 0.05)))
)

cat("\nCorrelation matrix dimensions (modules × traits):\n")
print(dim(mod_trait_cor))
cat("\nFirst 5 × all traits (rounded):\n")
print(round(mod_trait_cor[1:5, ], 3))

# 6.  Pretty heat-map with on-tile numbers ────────────────────────────────────
plot_pheatmap <- function(mat) {
  pheatmap(mat,
           color             = colorRampPalette(c("blue", "white", "red"))(100),
           cluster_rows       = TRUE,
           cluster_cols       = FALSE,       # keep trait order
           display_numbers    = TRUE,
           number_format      = "%.2f",
           fontsize_number    = 8,
           main               = "Module–trait correlations")
}

## A. show immediately in console / notebook
plot_pheatmap(mod_trait_cor)

## B. save high-resolution PNG
png("module_trait_heatmap.png", width = 3600, height = 2400, res = 300)
plot_pheatmap(mod_trait_cor)
dev.off()

cat("\nHeat-map displayed and saved as 'module_trait_heatmap.png'.\n")
```

### Manu cell 10 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 10.

```r
## ──────────────────── Chunk 13-A · Pick FDR-significant modules ─────────────
# Purpose  : For every subtype, keep modules with
#              • |r| ≥ sig_r   AND   FDR < q_FDR
#
# Inputs   : mod_trait_cor  – correlation matrix   (modules × traits)
#            mod_trait_fdr  – BH-FDR matrix        (modules × traits)
#
# Outputs  : mods_FDR – list; names = traits, values = eigengene labels ("MEblue")
# QC       : str(mods_FDR); lengths ≤ nrow(mod_trait_cor)

sig_r <- 0.50   # correlation threshold
q_FDR <- 0.05   # FDR threshold

trait_names <- colnames(mod_trait_cor)   # e.g. "SubtypeTNBC", …

pick_FDR <- function(trait) {
  keep <- abs(mod_trait_cor[, trait]) >= sig_r &
          mod_trait_fdr[, trait]      <  q_FDR
  rownames(mod_trait_cor)[keep]
}

mods_FDR <- setNames(lapply(trait_names, pick_FDR), trait_names)

cat("\n=== Significant modules (FDR rule only) ===\n")
print(lapply(mods_FDR, length))



## ──────────────────── Chunk 13-B · Eigengene → colour map (FDR) ─────────────
strip_ME <- function(me_vec) {
  cols <- sub("^ME", "", me_vec)         # "MEblue" → "blue"
  setdiff(cols, "turquoise")             # drop catch-all module
}

cols_FDR <- lapply(mods_FDR, strip_ME)

cat("\n=== Colour sets (FDR rule) ===\n")
print(cols_FDR)

stopifnot(!any(unlist(cols_FDR) == "turquoise"))


## ──────────────────── Chunk 13-C · Build gene ↔ module lookup ───────────────
# Purpose  : Produce a two-column data frame linking every gene (column of `expr`)
#            to its module colour.  Handles both colour-name and numeric labels.
#
# Inputs   : expr  – matrix [samples × genes]  (from Chunk 7)
#            net   – WGCNA network object      (from Chunk 10)
#
# Outputs  : geneMod – data.frame(Gene, Module)
#
# QC       :  • nrow(geneMod) == ncol(expr)
#            • table(geneMod$Module) equals module size tally in net

suppressPackageStartupMessages(library(WGCNA))

# ── 1.  Derive moduleColours safely ------------------------------------------
if (!exists("moduleColors", inherits = FALSE)) {
  moduleColors <- if (is.numeric(net$colors)) {
    labels2colors(net$colors)      # convert numeric labels to colours
  } else {
    net$colors                      # already plain colour names
  }
}

# sanity
stopifnot(length(moduleColors) == ncol(expr))

# ── 2.  Build lookup table ----------------------------------------------------
geneMod <- data.frame(
  Gene   = colnames(expr),          # each gene once
  Module = moduleColors,
  stringsAsFactors = FALSE
)

# ── 3.  Quick checks ----------------------------------------------------------
cat("\nLookup dims:", dim(geneMod), "\n")    # rows should equal # genes
cat("First 6 rows:\n"); print(head(geneMod))

cat("\nModule size tally (from lookup):\n")
print(sort(table(geneMod$Module), decreasing = TRUE))



## ──────────────────── Chunk 13-D · Extract FDR gene sets & persist ──────────
# Purpose : For each subtype, gather genes from FDR-significant modules
#           and save to "<Trait>_FDR_genes.csv".  Print a summary line.
#
# Inputs  : cols_FDR – list of colour vectors
#           geneMod  – data.frame(Gene, Module)
#
# Outputs : CSVs + console breadcrumb

save_gene_list <- function(g_vec, trait, col_vec) {
  out_file <- sprintf("%s_FDR_genes.csv", trait)
  write.csv(data.frame(Gene = g_vec), out_file, row.names = FALSE)
  cat(sprintf("%-15s | %4d genes | modules = %s\n",
              trait, length(g_vec), paste(col_vec, collapse = ", ")))
}

for (tr in names(cols_FDR)) {
  g_fdr <- geneMod$Gene[ geneMod$Module %in% cols_FDR[[tr]] ]
  save_gene_list(g_fdr, tr, cols_FDR[[tr]])
}

cat("\nAll FDR-controlled gene lists written.\n")
```

### Manu cell 13 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 13.

```r
###############################################################################
## 14-A  Adjacency   +   Intramodular Connectivity
###############################################################################
# Sanity: make sure expr is samples × genes
stopifnot(nrow(expr) == nrow(MEs),          # samples align
          ncol(expr) == length(moduleColors))

# Optional belt-and-braces check versus TOM size (if you saved TOM earlier)
# nGenes <- ncol(expr)
# stopifnot(nGenes == nrow(TOM) && nGenes == ncol(TOM))


softPower <- 6               # same as blockwiseModules
adjMat <- adjacency(expr, power = softPower, type = "signed")
IMC    <- intramodularConnectivity(adjMat, moduleColors)

cat("\nAdjacency dim :", dim(adjMat), "\n")
cat("IMC kWithin summary:\n"); print(summary(IMC$kWithin))

# ── QC plot: log-degree distribution ─────────────────────────────────────────
png("adjacency_degree_dist.png", 2400, 1800, res = 300)
hist(log10(rowSums(adjMat)), breaks = 60,
     main = "Log10 degree distribution",
     xlab = "log10(kTotal)", col = "steelblue")
dev.off()
deg_stats <- summary(rowSums(adjMat))
save(deg_stats, file = "degree_stats.RData")
```

### Manu cell 15 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 15.

```r
###############################################################################
## 14-B  Module-membership (kME)  +   QC
###############################################################################
kMEtab <- signedKME(expr, MEs, outputColumnName = "kME")

me_labels  <- sub("^kME", "", colnames(kMEtab))
colour_map <- labels2colors(me_labels)
colnames(kMEtab) <- paste0("kME", colour_map)

core_cols <- setdiff(unique(moduleColors), c("grey", "gold"))
stopifnot(all(paste0("kME", core_cols) %in% colnames(kMEtab)))
cat("kME table dim :", dim(kMEtab), "\n")

# ── Per-module kME summaries ────────────────────────────────────────────────
kME_summ <- t(vapply(core_cols, function(clr) {
  quantile(kMEtab[, paste0("kME", clr)], probs = c(.05,.25,.5,.75,.95))
}, numeric(5)))
print(kME_summ)
save(kMEtab, kME_summ, file = "kME_table.RData")
```

### Manu cell 16 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 16.

```r
###############################################################################
## 15  Master node data-frame  + extra QC
###############################################################################
masterNodes <- data.frame(
  Gene      = colnames(expr),
  Module    = moduleColors,
  kWithin   = IMC$kWithin,
  kME_value = NA_real_,
  stringsAsFactors = FALSE
)

idx <- cbind(seq_along(moduleColors),
             match(paste0("kME", moduleColors), colnames(kMEtab)))
masterNodes$kME_value <- kMEtab[idx]

no_eigengene <- moduleColors %in% c("grey", "gold")
if (any(is.na(masterNodes$kME_value[!no_eigengene]))) {
  stop("NA kME values found in non-grey/gold modules!")
}

cat("\nmasterNodes rows:", nrow(masterNodes),
    " | kME range (non-grey/gold):",
    range(masterNodes$kME_value[!no_eigengene], na.rm = TRUE), "\n")

# ── kME vs kWithin scatter & correlation ────────────────────────────────────
cor_k <- cor(masterNodes$kME_value[!no_eigengene],
             masterNodes$kWithin   [!no_eigengene])
cat("Pearson r(kME, kWithin) =", round(cor_k, 3), "\n")

png("kME_vs_kWithin.png", 2000, 1600, res = 300)
plot(masterNodes$kME_value, masterNodes$kWithin,
     pch = 19, cex = 0.3,
     col = scales::alpha(masterNodes$Module, 0.4),
     xlab = "kME", ylab = "kWithin",
     main = "kME vs intramodular connectivity")
abline(lm(kWithin ~ kME_value, masterNodes), col = "red")
dev.off()

write.csv(masterNodes, "masterNodes.csv", row.names = FALSE)
```

### Manu cell 17 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 17.

```r
top_n <- 10
hub_table <- do.call(rbind, lapply(setdiff(unique(moduleColors), c("grey", "gold")), function(mod) {
  df <- subset(masterNodes, Module == mod)
  df <- df[order(-df$kWithin), ]
  head(df, top_n)
}))
write.csv(hub_table, "top_hub_genes_by_module.csv", row.names = FALSE)
```

### Manu cell 18 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 18.

```r
library(ggplot2)
ggplot(masterNodes[!no_eigengene, ], aes(x = Module, y = kWithin)) +
  geom_boxplot() +
  theme_minimal() +
  ylab("kWithin") +
  xlab("Module") +
  ggtitle("Intramodular Connectivity (kWithin) by Module")
ggsave("boxplot_kWithin_by_module.png")

ggplot(masterNodes[!no_eigengene, ], aes(x = Module, y = kME_value)) +
  geom_boxplot() +
  theme_minimal() +
  ylab("kME") +
  xlab("Module") +
  ggtitle("Module Membership (kME) by Module")
ggsave("boxplot_kME_by_module.png")
```

### Manu cell 19 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 19.

```r
module_counts <- as.data.frame(table(masterNodes$Module))
write.csv(module_counts, "module_counts.csv", row.names = FALSE)
cat("\nModule size summary:\n"); print(module_counts)
```

### Manu cell 20 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 20.

```r
###############################################################################
## 16  Subtype-specific node exports  (+ colour-consistency check)
###############################################################################
TNBC_genes  <- read.csv("SubtypeTNBC_FDR_genes.csv")$Gene
HER2_genes  <- read.csv("SubtypeHER2pos_FDR_genes.csv")$Gene
ER_genes    <- read.csv("SubtypeERpos_FDR_genes.csv")$Gene

export_nodes <- function(gene_vec, cols_vec, label) {
  df <- subset(masterNodes, Gene %in% gene_vec)
  stopifnot(all(df$Module %in% cols_vec))       # colour guard
  out <- sprintf("%s_nodes.csv", label)
  write.csv(df, out, row.names = FALSE)
  cat(sprintf("%-15s : %5d genes written → %s\n",
              label, nrow(df), out))
}

export_nodes(TNBC_genes,  cols_FDR$SubtypeTNBC,   "SubtypeTNBC")
export_nodes(HER2_genes,  cols_FDR$SubtypeHER2pos,"SubtypeHER2pos")
export_nodes(ER_genes,    cols_FDR$SubtypeERpos,  "SubtypeERpos")
```

### Manu cell 21 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 21.

```r
for (subtype in c("SubtypeTNBC", "SubtypeHER2pos", "SubtypeERpos")) {
  # Load node set for this subtype
  nodes <- read.csv(sprintf("%s_nodes.csv", subtype))

  # Sort by kWithin, descending, and take top 20
  top_hubs <- nodes[order(-nodes$kWithin), ][1:20, ]

  # Export as CSV
  write.csv(top_hubs, sprintf("%s_top20_hub_genes.csv", subtype), row.names = FALSE)
}
```

### Manu cell 26 — hub-selection prefix only; edge export excluded

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 26.

```r
###############################################################################
## 16-B  |  Global hub genes & network  (top-50 kWithin per module)
## Input : masterNodes, adjMat
## Output: hubNodes.csv, hubEdges.csv  + console stats
###############################################################################
top_k <- 50
core_cols <- setdiff(unique(masterNodes$Module), c("grey","gold"))

hub_idx <- unlist(lapply(core_cols, function(clr) {
  g <- which(masterNodes$Module == clr)
  head(g[ order(masterNodes$kWithin[g], decreasing = TRUE) ], top_k)
}))

hub_idx <- unique(hub_idx)
hubNodes <- masterNodes[hub_idx, ]
```

### Manu cell 28 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 28.

```r
###############################################################################
## 16-C  |  Hub genes per subtype (top-50 per significant module)
## Input : masterNodes, kWithin, module colours per subtype
## Output: tnbcHubNodes.csv, her2HubNodes.csv, erHubNodes.csv + counts
###############################################################################
get_hubs <- function(mod_vec, label, k = 50) {
  idx <- unlist(lapply(mod_vec, function(clr) {
    g <- which(masterNodes$Module == clr)
    head(g[ order(masterNodes$kWithin[g], decreasing = TRUE) ], k)
  }))
  idx <- unique(idx)
  nodes <- masterNodes[idx, ]
  out <- sprintf("%sHubNodes.csv", tolower(label))
  write.csv(nodes, out, row.names = FALSE)
  cat(label, ": ", nrow(nodes), "hub genes →", out, "\n")
  nodes
}

tnbcMods <- c("greenyellow", "midnightblue")
her2Mods <- c("black", "yellow", "midnightblue", "magenta", "blue")
erMods   <- c("brown", "black")

tnbcNodes <- get_hubs(tnbcMods, "TNBC")
her2Nodes <- get_hubs(her2Mods, "HER2")
erNodes   <- get_hubs(erMods,   "ERpos")
```

### Manu cell 47 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 47.

```r
###############################################################################
## 17-Pre: Build *final* hub gene set (Methods-matched, no overlap/ambiguity)
###############################################################################
# Purpose: Select top 50 kWithin genes from exactly 7 subtype-module pairs,
#          using your explicit assignments.

# These are your assignments:
final_assignments <- data.frame(
  Module  = c("greenyellow", "midnightblue", "yellow", "magenta", "blue", "black", "brown"),
  Subtype = c("TNBC",       "TNBC",         "HER2pos", "HER2pos", "HER2pos", "ERpos", "ERpos"),
  stringsAsFactors = FALSE
)
# (No black for HER2, no midnightblue for HER2 or ERpos, just as you specify.)

final_hub_genes <- c()
final_hub_info  <- data.frame()  # Store gene, module, subtype

for(i in seq_len(nrow(final_assignments))) {
  mod   <- final_assignments$Module[i]
  sub   <- final_assignments$Subtype[i]
  idx   <- which(masterNodes$Module == mod)
  top50 <- idx[order(masterNodes$kWithin[idx], decreasing = TRUE)][1:50]
  genes <- masterNodes$Gene[top50]
  final_hub_genes <- c(final_hub_genes, genes)
  final_hub_info  <- rbind(final_hub_info,
                           data.frame(Gene = genes,
                                      Module = mod,
                                      Subtype = sub,
                                      stringsAsFactors = FALSE))
}

final_hub_genes <- unique(final_hub_genes)
cat("Final hub gene count (should be 350):", length(final_hub_genes), "\n")
cat("Subtype breakdown:\n")
print(table(final_hub_info$Subtype, final_hub_info$Module))

# Save for records/reproducibility
write.csv(final_hub_info, "final_hub_genes_info.csv", row.names = FALSE)
write.csv(data.frame(Gene=final_hub_genes), "final_hub_genes.csv", row.names = FALSE)
```

### Manu cell 93 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 93.

```r
## ──────────────────── Chunk 13-A · Pick winning modules ────────────────────
# Purpose : For every breast-cancer subtype, flag modules whose eigengenes
#           (a) correlate strongly (|r| ≥ sig_r) and
#           (b) pass *either*    raw-p <  p_raw      – exploratory
#                        or      FDR   <  q_FDR      – publication-grade
#
# Inputs  : mod_trait_cor   – matrix  (modules × traits)  from Chunk 12
#           mod_trait_pval  – matrix  (modules × traits)  ”    ”
#           mod_trait_fdr   – matrix  (modules × traits)  ”    ”
#           sig_r           – numeric; abs-corr threshold  (default 0.50)
#           p_raw, q_FDR    – numeric; p-value & FDR cut-offs
#
# Outputs : list  mods_rawP  – per trait, vector of eigengene labels (e.g. "MEblue")
#           list  mods_FDR   – per trait, vector of eigengene labels
#
# QC ideas: str(mods_rawP), str(mods_FDR); lengths should be ≤ nrow(mod_trait_cor)

# ── 0. Thresholds ────────────────────────────────────────────────────────────
sig_r <- 0.50
p_raw <- 0.05
q_FDR <- 0.05

# ── 1. Identify trait names (column names) ───────────────────────────────────
trait_names <- colnames(mod_trait_cor)         # e.g. "SubtypeTNBC", "SubtypeERpos", …

# ── 2. Helper to retrieve modules per rule ───────────────────────────────────
pick_modules <- function(trait, corr_mat, pmat, pthr) {
  keep <- abs(corr_mat[ , trait]) >= sig_r & pmat[ , trait] < pthr
  rownames(corr_mat)[ keep ]
}

# ── 3. Build the two lists in parallel ───────────────────────────────────────
mods_rawP <- setNames(lapply(trait_names, pick_modules,
                             corr_mat = mod_trait_cor,
                             pmat      = mod_trait_pval,
                             pthr      = p_raw),
                      trait_names)

mods_FDR  <- setNames(lapply(trait_names, pick_modules,
                             corr_mat = mod_trait_cor,
                             pmat      = mod_trait_fdr,
                             pthr      = q_FDR),
                      trait_names)

# ── 4. Console breadcrumb ----------------------------------------------------
cat("\n=== Significant modules (raw-p rule) ===\n")
print(lapply(mods_rawP, length))

cat("\n=== Significant modules (FDR rule) ===\n")
print(lapply(mods_FDR, length))


## ──────────────────── Chunk 13-B · Eigengene → colour map ───────────────────
# Purpose  : Convert eigengene labels (e.g. "MEblue") to their plain colour
#            names, and discard the default catch-all “turquoise”.
#
# Inputs   : mods_rawP – list of eigengene vectors (from 13-A, raw-p rule)
#            mods_FDR  – list of eigengene vectors (from 13-A, FDR rule)
#
# Outputs  : cols_rawP – list of colour vectors, same structure as mods_rawP
#            cols_FDR  – list of colour vectors, same structure as mods_FDR
#
# QC tips  : • confirm “turquoise” is absent
#            • counts match those printed in 13-A (minus any turquoise removals)

# ── 1. Helper – strip “ME” prefix and drop turquoise ─────────────────────────
strip_ME <- function(me_vec) {
  cols <- sub("^ME", "", me_vec)      # "MEblue" → "blue"
  setdiff(cols, "turquoise")          # remove if present
}

# ── 2. Apply to both significance schemes ───────────────────────────────────
cols_rawP <- lapply(mods_rawP, strip_ME)
cols_FDR  <- lapply(mods_FDR,  strip_ME)

# ── 3. Console breadcrumbs ---------------------------------------------------
cat("\n=== Colour sets (raw-p rule) ===\n")
print(cols_rawP)

cat("\n=== Colour sets (FDR rule) ===\n")
print(cols_FDR)

# Simple QC: ensure no turquoise
stopifnot(!any(unlist(cols_rawP) == "turquoise"),
          !any(unlist(cols_FDR)  == "turquoise"))




## ──────────────────── Chunk 13-C · Build gene ↔ module lookup ───────────────
# Purpose  : Produce a two-column data frame linking every gene (column of `expr`)
#            to its module colour.  Handles both colour-name and numeric labels.
#
# Inputs   : expr  – matrix [samples × genes]  (from Chunk 7)
#            net   – WGCNA network object      (from Chunk 10)
#
# Outputs  : geneMod – data.frame(Gene, Module)
#
# QC       :  • nrow(geneMod) == ncol(expr)
#            • table(geneMod$Module) equals module size tally in net

suppressPackageStartupMessages(library(WGCNA))

# ── 1.  Derive moduleColours safely ------------------------------------------
if (!exists("moduleColors", inherits = FALSE)) {
  moduleColors <- if (is.numeric(net$colors)) {
    labels2colors(net$colors)      # convert numeric labels to colours
  } else {
    net$colors                      # already plain colour names
  }
}

# sanity
stopifnot(length(moduleColors) == ncol(expr))

# ── 2.  Build lookup table ----------------------------------------------------
geneMod <- data.frame(
  Gene   = colnames(expr),          # each gene once
  Module = moduleColors,
  stringsAsFactors = FALSE
)

# ── 3.  Quick checks ----------------------------------------------------------
cat("\nLookup dims:", dim(geneMod), "\n")    # rows should equal # genes
cat("First 6 rows:\n"); print(head(geneMod))

cat("\nModule size tally (from lookup):\n")
print(sort(table(geneMod$Module), decreasing = TRUE))



## ──────────────────── Chunk 13-D · Extract gene sets & persist ──────────────
# Purpose  : For each subtype, create two gene lists:
#              • *_rawP  – modules that pass |r| ≥ sig_r & raw-p < 0.05
#              • *_FDR   – modules that pass |r| ≥ sig_r & BH-FDR < 0.05
#            Save each list to a CSV and print a concise console summary.
#
# Inputs   : • cols_rawP – list of colour vectors (from 13-B, raw-p rule)
#            • cols_FDR  – list of colour vectors (from 13-B, FDR rule)
#            • geneMod   – data.frame(Gene, Module)  (from 13-C)
#
# Outputs  : • CSV files, e.g.  SubtypeTNBC_rawP_genes.csv
#                                SubtypeTNBC_FDR_genes.csv
#            • Console breadcrumbs with counts and module colours
#
# QC ideas : • file.exists() on each CSV
#            • compare rawP vs FDR counts (rawP ≥ FDR is expected)
#            • optional Venn diagram per subtype

# ── 1.  Helper : write CSV + echo summary ------------------------------------
save_gene_list <- function(g_vec, trait, rule, col_vec) {
  out_file <- sprintf("%s_%s_genes.csv", trait, rule)
  write.csv(data.frame(Gene = g_vec), out_file, row.names = FALSE)
  cat(sprintf("%-15s | %-4s | %4d genes | modules = %s\n",
              trait, rule, length(g_vec), paste(col_vec, collapse = ", ")))
}

# ── 2.  Iterate over subtypes and both rules ---------------------------------
for (tr in names(cols_rawP)) {
  ## RAW-P RULE ----------------------------------------------------------------
  g_raw <- geneMod$Gene[ geneMod$Module %in% cols_rawP[[tr]] ]
  save_gene_list(g_raw, tr, "rawP", cols_rawP[[tr]])

  ## FDR RULE ------------------------------------------------------------------
  g_fdr <- geneMod$Gene[ geneMod$Module %in% cols_FDR [[tr]] ]
  save_gene_list(g_fdr, tr, "FDR",  cols_FDR [[tr]])
}

cat("\nAll gene lists written.  Inspect counts above and CSV files on disk.\n")
```

### Manu cell 107 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 107.

```r
# ─── QC: verify module counts & threshold criteria ──────────────────────────
r_th   <- 0.50      # effect-size threshold
p_th   <- 0.05      # raw-P threshold
fdr_th <- 0.05      # BH-FDR threshold

cat("\n=== QC: module–trait tests ============================================\n")
cat("Modules tested per trait:", nrow(mod_trait_cor), "\n")
cat(sprintf("Criteria: |r| ≥ %.2f  &  p < %.2f  &  FDR < %.2f\n\n",
            r_th, p_th, fdr_th))

## 1.  Logical matrix: does each module–trait pair pass?
pass_mat <- abs(mod_trait_cor) >= r_th &
            mod_trait_pval    <  p_th &
            mod_trait_fdr     <  fdr_th

## 2.  Per-trait summary
pass_count <- colSums(pass_mat)
for (tr in colnames(trait_mat)) {
  cat(sprintf("%-15s : %2d / %2d modules pass\n",
              tr, pass_count[tr], nrow(mod_trait_cor)))
}

## 3.  Detail failures, if any
fails <- which(!pass_mat, arr.ind = TRUE)
if (length(fails)) {
  cat("\n--- Modules that FAIL at least one criterion --------------------------\n")
  apply(fails, 1, function(idx) {
    mod <- rownames(mod_trait_cor)[idx[1]]
    tr  <- colnames(mod_trait_cor)[idx[2]]
    cat(sprintf("%s vs %-12s  r = %.3f,  p = %.3g,  FDR = %.3g\n",
                mod, tr,
                mod_trait_cor [idx[1], idx[2]],
                mod_trait_pval[idx[1], idx[2]],
                mod_trait_fdr [idx[1], idx[2]]))
  })
} else {
  cat("\nAll module–trait pairs meet the specified thresholds.\n")
}
cat("===========================================================================\n")




## List all selected eigengene labels  ----------------------------------------
cat("\n=== Raw-p rule: module labels per subtype ===\n")
for (tr in names(mods_rawP)) {
  cat(sprintf("%-12s : %s\n",
              tr,
              if (length(mods_rawP[[tr]]))
                paste(mods_rawP[[tr]], collapse = ", ")
              else "(none)"))
}

cat("\n=== FDR rule: module labels per subtype ===\n")
for (tr in names(mods_FDR)) {
  cat(sprintf("%-12s : %s\n",
              tr,
              if (length(mods_FDR[[tr]]))
                paste(mods_FDR[[tr]], collapse = ", ")
              else "(none)"))
}
```

### Manu cell 111 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 111.

```r
if (!requireNamespace("pheatmap", quietly = TRUE))
    install.packages("pheatmap")
library(pheatmap)


## ───────────────────────── Chunk 11 · Dendrogram & eigengene heat-map ──────
library(WGCNA)           # already loaded earlier
library(pheatmap)        # nice heat-map with labels; install if missing

## 1. Gene dendrogram with module colours
png("module_dendrogram_fixed.png", width = 2000, height = 1200, res = 200)
plotDendroAndColors(
  net$dendrograms[[1]],
  net$colors[ net$blockGenes[[1]] ],     # colours already stored in net
  groupLabels = "Modules",
  dendroLabels = FALSE,
  hang = 0.03,
  addGuide = TRUE,
  guideHang = 0.05
)
dev.off()

## 2. Eigengene–eigengene correlation matrix
me_cor <- cor(MEs, use = "pairwise.complete.obs")   # 279 × 20 → 20 × 20

write.csv(me_cor, "eigengene_correlation.csv")

# Publication-quality heat-map (pheatmap auto-adds row/col names)
png("module_eigengene_heatmap_high_res.png", width = 3600, height = 2400, res = 300)
pheatmap(me_cor,
         main         = "Module eigengene correlation",
         clustering_distance_rows = "correlation",
         clustering_distance_cols = "correlation",
         display_numbers = FALSE,
         legend        = TRUE,
         border_color  = NA)
dev.off()

## 3. Console summaries for the LLM
cat("\n=== Eigengene correlation matrix ===\n")
cat("Dimensions:", dim(me_cor), "\n")
cat("Range:", sprintf("[%.2f, %.2f]", min(me_cor), max(me_cor)), "\n\n")

cat("First 5 × 5 block:\n")
print(round(me_cor[1:min(5, nrow(me_cor)),
                   1:min(5, ncol(me_cor))], 3))
```

### Manu cell 112 — whole cell

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 112.

```r
## ───────────────────────── Chunk 12 · Module–trait correlation ─────────────
library(WGCNA)          # corPvalueStudent

## 1. Build one-hot matrix for Subtype (Normal = reference level)
trait_mat <- model.matrix(~ Subtype, metadata)[, -1]   # drops intercept
rownames(trait_mat) <- rownames(metadata)              # ensure matching order

## 2. Correlate module eigengenes with traits
mod_trait_cor  <- cor(MEs, trait_mat, use = "pairwise.complete.obs")
mod_trait_pval <- corPvalueStudent(mod_trait_cor, nSamples = nrow(metadata))
mod_trait_fdr  <- apply(mod_trait_pval, 2, p.adjust, method = "BH")

## 3. Save full matrices
write.csv(mod_trait_cor,  "module_trait_correlations.csv")
write.csv(mod_trait_pval, "module_trait_pvalues.csv")
write.csv(mod_trait_fdr,  "module_trait_FDR.csv")

## 4. Tidy summary table (one row per module, three traits)
moduleTraitResults <- data.frame(
  Module            = rownames(mod_trait_cor),
  ERpos_Corr        = mod_trait_cor[ , "SubtypeERpos"],
  ERpos_FDR         = mod_trait_fdr [ , "SubtypeERpos"],
  TNBC_Corr         = mod_trait_cor[ , "SubtypeTNBC"],
  TNBC_FDR          = mod_trait_fdr [ , "SubtypeTNBC"],
  HER2pos_Corr      = mod_trait_cor[ , "SubtypeHER2pos"],
  HER2pos_FDR       = mod_trait_fdr [ , "SubtypeHER2pos"]
)
write.csv(moduleTraitResults, "module_trait_summary.csv", row.names = FALSE)

## 5. Quick console read-out for LLM
cat("\n=== Top module–trait associations (|r| ≥ 0.4, FDR < 0.05) ===\n")
print(
  subset(moduleTraitResults,
         (abs(ERpos_Corr)  >= 0.4 & ERpos_FDR  < 0.05) |
         (abs(TNBC_Corr)   >= 0.4 & TNBC_FDR   < 0.05) |
         (abs(HER2pos_Corr)>= 0.4 & HER2pos_FDR< 0.05))
)

cat("\nMatrix dimensions (modules × traits):\n")
print(dim(mod_trait_cor))

cat("\nFirst 5 × 3 block of correlation matrix:\n")
print(round(mod_trait_cor[1:5, ], 3))

## 6. Optional heat-map for immediate visual QC
png("module_trait_heatmap_high_res.png", width = 2400, height = 1800, res = 300)
heatmap(mod_trait_cor,
        Rowv = NA, Colv = NA, scale = "none",
        main = "Module–trait correlation",
        margins = c(7, 8))
dev.off()
```

### February cell 2 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 2.

```r
# Choose a set of soft-threshholding powers
power <- c(c(1:20), seq(from = 12, to = 50, by = 2))
power

## RunpickSoftThreshold
sft <- pickSoftThreshold(
	data,
	powerVector = power,
	networkType = "signed",
	verbose = 5
)


sft.data <- sft$fitIndices
names(sft.data)

# Ensure necessary libraries are loaded
library(ggplot2)
library(gridExtra)  # For arranging multiple plots

a1 <- ggplot(sft.data, aes(x = Power, y = SFT.R.sq, label = Power)) +
  geom_point(size = 3, color = 'blue') +
  geom_text(nudge_y = 0.05, size = 3) +
  geom_hline(yintercept = 0.8, color = 'red') +
  labs(x = 'Soft Threshold (Power)',
       y = 'Scale-Free Topology Fit Index',
       title = 'Scale-Free Topology') +
  theme_classic()

a2 <- ggplot(sft.data, aes(x = Power, y = mean.k., label = Power)) +
  geom_point(size = 3, color = 'red') +
  geom_text(nudge_y = 50, size = 3) +
  labs(x = 'Soft Threshold (Power)',
       y = 'Mean Connectivity',
       title = 'Mean Connectivity') +
  theme_classic()

ggsave("scale_free_topology.png", grid.arrange(a1, a2, ncol = 2), width = 10, height = 5)

write.csv(sft.data, "soft_thresholding_results.csv")


# Temporarily override the default correlation function for WGCNA
# temp_cor <- cor
# cor <- WGCNA::cor


# Ensure Data is Properly Transposed (Samples x Genes)
#cat("Data dimensions (samples x genes):", dim(data), "\n")

# Enable Parallel Processing to Speed Up Computation
#enableWGCNAThreads()

# Re-run blockwiseModules for Module Detection
softPower <- 6  # Use the previously selected soft-thresholding power

net <- blockwiseModules(
  data,
  power = softPower,                # Soft-thresholding power
  maxBlockSize = 26000,             # Adjust based on the number of genes
  TOMType = "signed",               # Use a signed network
  minModuleSize = 30,               # Minimum number of genes per module
  reassignThreshold = 0,            # Threshold for reassigning genes
  mergeCutHeight = 0.25,            # Threshold for merging similar modules
  numericLabels = TRUE,             # Use numeric module labels
  randomSeed = 1234,               # For reproducibility
  saveTOMs = TRUE,                  # Save the TOM for future use
  saveTOMFileBase = "TOM",          # File prefix for TOM
  verbose = 3                       # Display detailed progress
)
```

### February cell 3 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 3.

```r
load("TOM-block.1.RData")  # e.g. "TOM-block.1.RData"
# If it loads as a "dist" class (commonly used for large matrices),
# convert carefully to a matrix ONLY if you really need all ~26k x 26k:
TOM <- as.matrix(TOM)
summary(diag(TOM))
# If near 0 → you have the dissimilarity (1 - actualTOM).
TOM <- 1 - TOM
# Now diag(TOM) should be near 1.
summary(diag(TOM))
# If near 0 → you have the dissimilarity (1 - actualTOM).
```

### February cell 5 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 5.

```r
# Extract Results
moduleLabels <- net$colors  # Module labels for each gene
moduleColors <- labels2colors(moduleLabels)  # Convert numeric labels to colors
MEs <- net$MEs  # Module eigengenes (summary expression profiles of modules)
# TOM <- 1 - net$dissTOM  # Topological overlap matrix (for network construction)

# Create a mapping between module labels and module colors, using the ME names from the eigengenes.
mapping_df <- unique(data.frame(
  ModuleLabel = paste0("ME", moduleLabels),  # add the "ME" prefix
  ModuleColor = moduleColors
))
print(mapping_df)
# Save mapping_df mapping as CSV
write.csv(mapping_df, "module_label_color_mapping.csv", row.names = FALSE)

# Save Results
save(moduleLabels, moduleColors, MEs, TOM, file = "WGCNA_results_full.RData")

# Summarize Modules
moduleSummary <- table(moduleColors)
write.csv(moduleSummary, "module_summary.csv")  # Save summary as CSV

cat("Number of modules detected:", length(unique(moduleColors)), "\n")
cat("Modules detected (colors):", unique(moduleColors), "\n")

# Plot and Save Module Dendrogram
plotDendroAndColors(
  net$dendrograms[[1]],               # Dendrogram for block 1
  moduleColors[net$blockGenes[[1]]],  # Module colors for block 1
  "Dynamic Tree Cut",                 # Title
  dendroLabels = FALSE,               # No labels on dendrogram
  hang = 0.03,                        # How much to hang the branches
  addGuide = TRUE,                    # Add guide lines for visualization
  guideHang = 0.05                    # Height of guide lines
)
ggsave(
  "module_dendrogram_fixed.png",
  width = 50,  # Adjust to appropriate size
  height = 30, # Adjust to appropriate size
  dpi = 300,   # Specify DPI for high resolution
  limitsize = FALSE
)

# High-Resolution Heatmap of Module Eigengenes
MEcor <- cor(MEs)
png("module_eigengene_heatmap_high_res.png", width = 3600, height = 2400, res = 300)
heatmap(
  as.matrix(cor(MEs)),         # Correlation matrix of module eigengenes
  symm = TRUE,                 # Symmetric heatmap
  main = "Module Eigengene Correlation Heatmap"
)
dev.off()

# Gene-to-Module Assignments
geneModuleAssignments <- data.frame(Gene = colnames(data), Module = moduleColors)
write.csv(geneModuleAssignments, "gene_module_assignments.csv")

# View the first few rows of assignments
head(geneModuleAssignments)
```

### February cell 6 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 6.

```r
# Ensure Metadata and Module Eigengenes Are Aligned
stopifnot(rownames(metadata) == rownames(MEs))  # Ensure samples match

# Convert Subtypes to Dummy Variables
trait_matrix <- model.matrix(~ category, data = metadata)[, -1]  # Dummy variables for subtypes
rownames(trait_matrix) <- rownames(metadata)  # Align sample IDs

# Output the Dummy Matrix for Review
cat("Trait Matrix (Dummy Variables):\n")
print(head(trait_matrix))



# Compute Correlations Between MEs and Traits
module_trait_cor <- cor(MEs, trait_matrix, use = "pairwise.complete.obs")

# Compute P-Values for Correlations
module_trait_pval <- corPvalueStudent(module_trait_cor, nrow(metadata))

# Save Results as Matrices
write.csv(module_trait_cor, "module_trait_correlations.csv")
write.csv(module_trait_pval, "module_trait_pvalues.csv")

# Combine Correlations and P-Values into a DataFrame for Easy Interpretation
moduleTraitResults <- data.frame(
  Module = rownames(module_trait_cor),
  TNBC_Correlation = module_trait_cor[, "categoryTNBC"],
  TNBC_P.value = module_trait_pval[, "categoryTNBC"],
  HER2_Correlation = module_trait_cor[, "categoryHER2+"],
  HER2_P.value = module_trait_pval[, "categoryHER2+"],
  ER_Correlation = module_trait_cor[, "categoryER+"],
  ER_P.value = module_trait_pval[, "categoryER+"]
)

# Save Combined Results
write.csv(moduleTraitResults, "module_trait_summary.csv")
cat("Module-Trait Results Saved as 'module_trait_summary.csv'\n")



# Prepare Data for Heatmap
install.packages('pheatmap')
library(pheatmap)

# Focus on Correlation Data
corHeatmapData <- module_trait_cor
rownames(corHeatmapData) <- paste("ME", rownames(corHeatmapData), sep = "_")
colnames(corHeatmapData) <- colnames(module_trait_cor)
# colnames(corHeatmapData) <- c("TNBC", "HER2+", "ER+")

# High-Resolution Heatmap
png("module_trait_heatmap.png", width = 3600, height = 2400, res = 300)
pheatmap(
  corHeatmapData,
  cluster_rows = TRUE,
  cluster_cols = FALSE,
  display_numbers = TRUE,
  number_format = "%.2f",
  main = "Module-Trait Correlations",
  color = colorRampPalette(c("blue", "white", "red"))(100)
)
dev.off()

cat("Heatmap saved as 'module_trait_heatmap.png'.\n")
```

### February cell 11 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 11.

```r
# Define thresholds for module selection
cor_threshold <- 0.5  # Minimum correlation strength (can be adjusted)
pval_threshold <- 0.05  # Significance level

# Identify significantly correlated modules for each subtype
significant_modules_TNBC <- moduleTraitResults$Module[
  abs(moduleTraitResults$TNBC_Correlation) > cor_threshold &
  moduleTraitResults$TNBC_P.value < pval_threshold
]

significant_modules_HER2 <- moduleTraitResults$Module[
  abs(moduleTraitResults$HER2_Correlation) > cor_threshold &
  moduleTraitResults$HER2_P.value < pval_threshold
]

significant_modules_ER <- moduleTraitResults$Module[
  abs(moduleTraitResults$ER_Correlation) > cor_threshold &
  moduleTraitResults$ER_P.value < pval_threshold
]
```

### February cell 13 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 13.

```r
convert_me_to_color <- function(modules, mapping_df) {
  mapped_colors <- mapping_df$ModuleColor[match(modules, mapping_df$ModuleLabel)]
  return(mapped_colors)
}

significant_modules_TNBC_colors <- convert_me_to_color(significant_modules_TNBC, mapping_df)
significant_modules_HER2_colors <- convert_me_to_color(significant_modules_HER2, mapping_df)
significant_modules_ER_colors   <- convert_me_to_color(significant_modules_ER,   mapping_df)

# Remove the turquoise module if it is present
significant_modules_TNBC_colors <- significant_modules_TNBC_colors[significant_modules_TNBC_colors != "turquoise"]
significant_modules_HER2_colors <- significant_modules_HER2_colors[significant_modules_HER2_colors != "turquoise"]
significant_modules_ER_colors   <- significant_modules_ER_colors[significant_modules_ER_colors != "turquoise"]


cat("TNBC Modules in Colors:\n", significant_modules_TNBC_colors, "\n")
cat("HER2+ Modules in Colors:\n", significant_modules_HER2_colors, "\n")
cat("ER+ Modules in Colors:\n", significant_modules_ER_colors, "\n")
```

### February cell 14 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 14.

```r
# --- Step 3: Extract genes using the converted colors ---
extract_genes <- function(modules, gene_data) {
  modules <- as.character(modules)
  gene_data$Module <- as.character(gene_data$Module)
  return(gene_data$Gene[gene_data$Module %in% modules])
}

TNBC_genes <- extract_genes(significant_modules_TNBC_colors, geneModuleAssignments)
HER2_genes <- extract_genes(significant_modules_HER2_colors, geneModuleAssignments)
ER_genes   <- extract_genes(significant_modules_ER_colors, geneModuleAssignments)

cat("TNBC genes extracted:", length(TNBC_genes), "\n")
cat("HER2+ genes extracted:", length(HER2_genes), "\n")
cat("ER+ genes extracted:", length(ER_genes), "\n")
```

### February cell 16 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 16.

```r
nGenes <- ncol(data)   # after your final data transpose, data has samples x genes
stopifnot(nGenes == ncol(TOM) && nGenes == nrow(TOM))
```

### February cell 18 — whole cell

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 18.

```r
###############################################################################
# 1) Compute adjacency (if not available)
###############################################################################
# Make sure 'data' is samples x genes. If your 'data' is genes x samples, do 't(data)'
softPower <- 6
adjacencyMat <- adjacency(
  data,        # samples x genes
  power = softPower,
  type  = "signed"
)


###############################################################################
# 2) Compute kME (module membership)
###############################################################################
# We already have MEs from your blockwiseModules. MEs is also samples x #modules.
# signedKME() expects 'datExpr' with rows = samples, columns = genes,
# exactly what we have if 'data' is samples x genes.
library(WGCNA)
kMEtable <- signedKME(
  data,     # samples x genes
  MEs,
  outputColumnName = "kME"
)
# This results in columns: kMEblack, kMEblue, kMEbrown, etc., for each module color.


###############################################################################
# 3) Compute intramodular connectivity (IMC)
###############################################################################
IMC <- intramodularConnectivity(
  adjMat = adjacencyMat,  # Must be genes x genes, see note below
  colors = moduleColors      # The same color vector from WGCNA
)

# Note: For adjacencyMat to be genes x genes, we might need to transpose 'data'
#   if our adjacency() call used 'rows = samples, columns = genes'.
#   The WGCNA function adjacency() usually returns a genes x genes matrix
#   if columns = genes. You can confirm with: dim(adjacencyMat).


###############################################################################
# 4) Build a Master Node Data Frame
###############################################################################
# Let’s assume:
#   - colnames(data) is the vector of gene names in the same order as adjacencyMat,
#   - geneModuleAssignments is a data frame with "Gene" and "Module".

allGenes <- colnames(data)  # vector of gene names
# Or if you have it as rownames of adjacencyMat, you can do: allGenes <- rownames(adjacencyMat)

# Build a data frame of gene info
masterNodes <- data.frame(
  Gene          = allGenes,
  Module        = moduleColors,               # same order as 'allGenes'
  kME_value     = NA,                         # placeholder
  kWithin       = IMC$kWithin,                # intramodular connectivity
  stringsAsFactors = FALSE
)

# Fill in each gene's actual kME for its assigned module
# e.g. if gene i is in "brown" module, then we grab kMEtable[i, "kMEbrown"]
for(i in seq_along(allGenes)) {
  geneColor <- moduleColors[i]
  # The columns of kMEtable are named kMEblack, kMEbrown, etc.
  kMEcolName <- paste0("kME", geneColor)
  masterNodes$kME_value[i] <- kMEtable[i, kMEcolName]
}


###############################################################################
# 5) Merge (Optional) Additional Columns
###############################################################################
# If you have per-gene correlations to the traits (TNBC vs. Normal, etc.),
# you could add them if you have them in a vector or data frame.
# For example, suppose you computed "geneCorr_TNBC" somehow.
# We'll skip that for brevity, but you can do:
# masterNodes$TNBC_corr <- geneCorr_TNBC
# ... and so on.


###############################################################################
# 6) Subset for Each Subtype and Write CSV
###############################################################################
# We assume you already have:
# TNBC_genes, HER2_genes, ER_genes
# These are vectors of gene names deemed significant for each subtype.

TNBC_nodes <- masterNodes[ masterNodes$Gene %in% TNBC_genes, ]
HER2_nodes <- masterNodes[ masterNodes$Gene %in% HER2_genes, ]
ER_nodes   <- masterNodes[ masterNodes$Gene %in% ER_genes, ]

write.csv(TNBC_nodes, "TNBC_nodes.csv", row.names = FALSE)
write.csv(HER2_nodes, "HER2_nodes.csv", row.names = FALSE)
write.csv(ER_nodes,   "ER_nodes.csv",   row.names = FALSE)

# That’s it! Now you have 3 node CSV files, each containing:
#   Gene, Module, kME_value, kWithin
# And you can add or remove columns as desired.
```

## Additional verbatim comparison evidence outside the selected path

These cells fill extraction gaps; none is a required selected baseline step. Cell 46 is input/hub inventory only, despite its ML-oriented heading; no model code is included. Error outcomes are documented above, not inferred from the executable blocks.

### Manu cell 4 — whole cell, outside selected path

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 4.

```r
## 5. Quick summaries for the LLM
cat("\n=== Soft-threshold table ===\n")
print(head(sft_df, 10))
cat("\nSummary stats\n")
print(summary(sft_df))
```

### Manu cell 22 — whole cell, outside selected path

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 22.

```r
for (subtype in c("SubtypeTNBC", "SubtypeHER2pos", "SubtypeERpos")) {
  nodes <- read.csv(sprintf("%s_nodes.csv", subtype))
  top_hubs <- nodes[order(-nodes$kWithin), ][1:20, ]

  cat(sprintf("\n=== Top 20 Hub Genes for %s (sorted by kWithin) ===\n", subtype))
  print(top_hubs)

  write.csv(top_hubs, sprintf("%s_top20_hub_genes.csv", subtype), row.names = FALSE)
}
```

### Manu cell 46 — whole cell, outside selected path

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 46.

```r
###############################################################################
## 17-A.0  Verify and Echo ML Inputs
###############################################################################

# 1. Expression matrix (should be samples × genes)
cat("expr: ", nrow(expr), "samples ×", ncol(expr), "genes\n")
cat("First 5 sample IDs: ", paste(rownames(expr)[1:5], collapse = ", "), "\n")
cat("First 5 gene symbols: ", paste(colnames(expr)[1:5], collapse = ", "), "\n")

# 2. Sample labels (subtype annotation)
cat("Subtype label vector: ", length(metadata$Subtype), " samples\n")
cat("Subtype levels: ", paste(levels(metadata$Subtype), collapse = ", "), "\n")
cat("Subtype distribution:\n")
print(table(metadata$Subtype))

# 3. Hub gene lists (from previous chunks)
cat("TNBC hub genes:", length(TNBC_genes), "\n")
cat("HER2 hub genes:", length(HER2_genes), "\n")
cat("ERpos hub genes:", length(ER_genes), "\n")

cat("First 5 TNBC hub genes:", paste(head(TNBC_genes, 5), collapse = ", "), "\n")
cat("First 5 HER2 hub genes:", paste(head(HER2_genes, 5), collapse = ", "), "\n")
cat("First 5 ERpos hub genes:", paste(head(ER_genes, 5), collapse = ", "), "\n")

# Optionally, check overlap
all_hubs <- unique(c(TNBC_genes, HER2_genes, ER_genes))
cat("Total unique hub genes:", length(all_hubs), "\n")
cat("Any overlapping hub genes across subtypes?:",
    any(duplicated(c(TNBC_genes, HER2_genes, ER_genes))), "\n")

# Optionally, print a Venn/UpSet plot here if desired!
```

### Manu cell 119 — whole cell, outside selected path

Source: `notebooks/original/Original_Manu_Pipe.ipynb`, JSON position 119.

```r
# --- Reporting & Output: ---
cat("Network object type:\n"); print(class(net))
cat("\nNames in network object:\n"); print(names(net))
cat("\nModule labels (first 20):\n"); print(head(net$colors, 20))
cat("\nNumber of modules detected:\n"); print(length(unique(net$colors)))
cat("\nModule sizes:\n"); print(table(net$colors))
cat("\nFirst 20 gene assignments:\n"); print(head(data.frame(Gene=colnames(expr), Module=net$colors), 20))
```

### February cell 15 — whole cell, outside selected path

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 15.

```r
module_counts <- table(geneModuleAssignments$Module)
print(module_counts)
```

### February cell 17 — whole cell, outside selected path

Source: `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb`, JSON position 17.

```r
# Example: For TNBC
TNBC_nodes <- geneModuleAssignments[geneModuleAssignments$Gene %in% TNBC_genes, ]
# This includes columns "Gene" and "Module"

# Optionally, add more columns: e.g., kME, annotation, etc.
# For example:
#   TNBC_nodes$kME <- ...
#   TNBC_nodes$Description <- ...
# Save to CSV
write.csv(TNBC_nodes, "TNBC_nodes.csv", row.names = FALSE)

# Repeat for HER2+ and ER+:
HER2_nodes <- geneModuleAssignments[geneModuleAssignments$Gene %in% HER2_genes, ]
write.csv(HER2_nodes, "HER2_nodes.csv", row.names = FALSE)

ER_nodes <- geneModuleAssignments[geneModuleAssignments$Gene %in% ER_genes, ]
write.csv(ER_nodes, "ER_nodes.csv", row.names = FALSE)

head(TNBC_nodes)
head(HER2_nodes)
head(ER_nodes)
```


## Faithful runner implementation (not executed)

`scripts/baseline/wgcna.R` implements cell 1's non-install setup and Manu cells **3 → 5 → 6 → 9 → 10 → 13 → 15 → 16 → 47**. The selected cells are embedded directly, with cell 9's installation statement omitted. Cell 1 retains the DESeq2 → limma → WGCNA load order, `enableWGCNAThreads()` without an explicit count, and the correlation binding. All analytical omissions, duplicated powers, power 6, turquoise exclusion, positional consumers and provisional cell 15 remapping remain unchanged. No alternative analysis or optional export is added. All 37 existing verbatim R notebook blocks remain unchanged.

Run only after independent code/environment review and separate execution authorization, in a fresh `Rscript` process from the repository root with project-local renv active. The intended command is `Rscript scripts/baseline/wgcna.R`; it has **not** been run. Parsing must use `parse(file=...)`, never `source()`. The runner rejects interactive use, the wrong branch and a dirty tree. It records the execution commit rather than requiring implementation's parent HEAD `9e89668`, because the reviewed implementation will necessarily have a new commit. It never commits or installs anything.

### Input bridge and isolation

The fixed bridge reads the reviewed preprocessing run `Results/baseline_preprocessing/run-20261013T053229Z-205981/`. SHA-256 identities measured read-only during implementation are pinned in the script:

| Input | SHA-256 |
| --- | --- |
| `expression_samples_by_genes.rds` | `c5d30758d2fdad1bbb980845958e61370c7a67592130f6e41b4ec0837449b3b4` |
| `aligned_metadata.rds` | `c6b766098f7d4dea34e60fa7b7167994f4845d983f5a57366547713a77a04644` |
| `execution_provenance.rds` | `10bae632b4abd190267bd960640d265ece960b5616841aca65de213ced20f9c7` |

Before analysis it verifies these identities, upstream completed status, numeric finite 279 × 25,750 expression, 279 × 2 metadata, unique nonempty unmodified identifiers, identical sample order and exact unordered batch/Subtype factor levels with all labels represented. It neither clips negative values nor transposes, filters, repairs or reorders inputs. The pinned file identity anchors gene identity to the reviewed preprocessing artifact; gene IDs are also explicitly checked and recorded.

A newly created `Results/baseline_wgcna/run-<UTC>-<PID>/` becomes the working directory before any source-derived relative write. Creation fails on collision. All notebook output names therefore stay inside a new run; historical files and previous runs are never reused. The wrapper creates no additional tracked dependency or configuration file.

### Provenance, lifecycle and validation

The runner records repository branch/commit/status/diff summary, input and source/script/lock/specification hashes, upstream provenance, identifiers/factors, all locked package versions and resolved project-library locations, function formals, effective threshold block size and construction settings, actual network block sizes and internal goodSamples/goodGenes. It checks locked R and Bioconductor settings and every locked package version before analysis. Session information, BLAS/LAPACK identity and resolved BLAS path, contrast options, detected logical/physical cores, `lscpu`, process affinity/cgroup information, cgroup-v2 ancestor quotas/limits and initial memory events are recorded. Missing platform files are labelled unavailable; memory-capacity admission requires a readable standard unified cgroup-v2 hierarchy; unsupported or unknown layouts fail closed. Effective WGCNA workers and relevant thread environment variables are captured immediately after unchanged setup.

Warnings are recorded immediately with stage, UTC time, message and call without muffling them; errors record stage/call context and failed analysis status. Stage starts and finishes persist provenance using temporary files in the same directory and checked atomic renames. Each file is replaced independently; the RDS is authoritative, and a kill between replacements may leave the text summary older. The last successfully renamed stage record survives an interrupted subsequent write; failed temporary files are retained for diagnosis. Output is split to the console and execution.log; sink(type="message") redirects original messages to execution.log, not external stderr. Parent message handlers promptly flush a labelled duplicate before the default message write; warning/error handlers and stage boundaries also flush. Arbitrary native output and the default message copy can remain buffered. Fork-worker warnings may not reach the parent warning handler, as in the notebook. No flush or persistence mechanism promises survival after SIGKILL. A normal caught failure finalizes partial provenance/session information and an artifact manifest, then exits unsuccessfully. Failures in finalization itself can leave incomplete diagnostic files and no completion marker. SIGKILL/OOM cannot run R handlers; external capture remains required.

The resource-management adaptation removes `adjMat` after **all of cell 13**, followed by `gc()`. `sft` is retained: removing its small result table offers no useful resource benefit. `sft_df` remains available and `IMC` remains through cell 16 and final validation. These changes alter notebook object retention/collection timing, not analytical choices. WGCNA internals are unchanged; full adjacency is never serialized for diagnostics.

Before completion the runner validates identifier order, a complete 350-row manual panel, required nonempty artifacts, CSV row counts and selected identifier readbacks, PNG signatures, and isolated RData readbacks. Saved TOMs are read one at a time to verify packed type/size/length; this can itself require approximately 2.47 GiB plus decompression overhead. PNG signature checks are not a full rendering test. Assertions report discrepancies and fail without repairing selections or remapping kME. In particular, unchanged cell 15 may stop the run; successful dimensions do not establish kME identity.

After the analytical tryCatch, graphics.off() closes every graphics device on success and caught failure, before any hashing. Closure errors are recorded as failure diagnostics and prohibit COMPLETED. This finalizes Rplots.pdf, a generated side file opened by the source grid/on-screen plots under Rscript, and any PNG left open on failure. Running cells inside main() also suppresses top-level autoprint (for example dev.off() return values); explicit print/cat and analytical calls are unchanged. These are wrapper adaptations. Finalization errors receive a best-effort separate finalization_failure.txt; failed writes or validation never authorize a completion marker.

After output checks and device closure, finalized provenance/session/log files and all artifacts are SHA-256 hashed into `artifact_checksums.csv`, with a second hash pass. `COMPLETED` is published last by a checked same-directory temporary-file rename, containing the manifest hash; the manifest excludes itself and the completion marker to avoid recursive hashes. Only a valid marker plus verified manifest establishes runner completion. A partial TOM file, a finished construction stage, or an internal `analysis_status=completed` without the final marker does not establish completion. These checks do not establish scientific validity or historical result agreement.

### Reviewed resource envelope and proposed execution monitoring

The independently reviewed planning envelope is **provisional 64 GiB RAM, 8 vCPUs, and 50–100 GiB free storage** on a dedicated machine. Peak memory and runtime remain **unmeasured**; this is not a success guarantee. A 32 GiB machine has less margin for copies, worker overhead, garbage collection and native allocations. Current WSL memory is inadequate for planning the faithful full-matrix stages. The recollection of a historical 64 GB machine is not a historical peak measurement.

For 25,750 genes, each full double gene-pair matrix is **4.94020 GiB**, packed distance/TOM is **2.47000 GiB**, and a full integer/logical matrix is **2.47010 GiB**, excluding identifiers/headers. Expression is **0.05353 GiB**. Thresholding uses 1,737-gene rectangular blocks (**0.33325 GiB** per full block matrix) and several cached/temporary powered matrices, distributed across workers. Network construction uses **one 25,750-gene block** if all genes pass internal checks: `maxBlockSize=26000` does not constrain this input to small blocks. Native adjacency plus TOM alone is **9.88040 GiB**; packed conversions, integer/logical indexing, dissimilarity, clustering and BLAS workspaces add memory. `as.dist.default` explicitly uses `m[row(m) > col(m)]`. Cell 13 independently creates full signed adjacency; local diagonal modification and `apply`/`aperm` working copies can coexist with caller adjacency, approximately **14.82060 GiB** for three double matrices before other allocations. Later membership is genes × eigengenes, not genes × genes (approximately **0.00384 GiB** at 20 eigengenes). Historical module counts/sizes are planning examples, not enforced network results.

Source evidence inspected for the assessment: WGCNA 1.74 `R/Functions.R` (`pickSoftThreshold`, `blockSize`, `adjacency`, `intramodularConnectivity`, `signedKME`); `R/blockwiseModulesC.R` (TOM conversion/dissimilarity/clustering); `src/networkFunctions.c` (native adjacency/TOM and BLAS multiplication); `src/corFunctions.c` (correlation workspaces); installed R `as.dist.default` and `apply`. Plausible whole-stage memory allowances are roughly 3–8 GiB for thresholding and 20–30+ GiB for large network/connectivity stages in a controlled session; these are estimates, not measured peaks or upper bounds. Retained sessions, allocator behavior, native libraries and worker lifetimes remain uncertain.

**Reference BLAS is the proposed first-run environment**. Reference BLAS performs TOM matrix multiplication single-threadedly; additional vCPUs do not accelerate that multiplication. Runtime is unmeasured and may be substantial; no review timing estimate is a benchmark. Before execution, independently verify the actual BLAS target, R build and thread behavior and review the runner's recorded identity; the runner records rather than automatically changes BLAS. Historical BLAS is unknown. Eight detected cores normally give seven workers through unchanged `enableWGCNAThreads()`; detected cores may exceed a VM/container quota. Review recorded affinity/quota and avoid unintended nested BLAS oversubscription. No thread limits are changed by this implementation.

For authorized execution, use a **dedicated cgroup wherever possible** and an external supervisor. Capture initial/final and periodic cgroup memory usage, peak and `memory.events` (including OOM/OOM-kill deltas), limits and CPU quotas; preserve records outside the R process and collect final events after workers exit. A dedicated cgroup's aggregate accounting is preferable to summing worker RSS, which overcounts fork-shared memory. GNU `/usr/bin/time -v` is useful for elapsed time, exit/signal status and RSS reporting, but **does not measure aggregate concurrent worker memory**. Preserve external stdout/stderr, exit/signal records and available kernel/journal OOM evidence; exit 137 alone does not prove OOM. Do not rely on R finalizers after SIGKILL. Monitoring/provisioning is not implemented or run by this task.

For cloud preparation, transfer pinned RDS inputs/upstream provenance, repository source/specifications and renv bootstrap/settings/lock; verify transfer hashes. Restore the locked project environment on compatible Linux with required build/system dependencies without updating the lock. Verify BLAS, actual guest/cgroup capacity and monitoring before separately authorized analysis. Retrieve outputs, manifests, logs, session/package records and external failure/OOM records; verify hashes and completion before cleanup. Then terminate compute and remove temporary volumes/snapshots/credentials according to approved retention. No current pricing was selected and no resources were provisioned.

The authorized .gitignore addition now excludes `/Results/baseline_wgcna/`, following the preprocessing convention. It must be part of the reviewed clean checkout before execution so generated files do not prevent retries or enter Git accidentally.

### Review corrections: capacity and native network handling

Before package setup/thresholding, the wrapper records guest MemTotal and all readable current/ancestor cgroup-v2 memory.max limits. Effective capacity is their minimum, excluding swap. The admission minimum is **60 GiB** for the nominal 64 GiB target, allowing normal guest overhead. Unknown, unreadable, unsupported v1/hybrid/nonstandard mount layouts, visible non-root hierarchy mounts or insufficient capacity are rejected, with observed capacity/status persisted and logged. This is a capacity safeguard, not an available-memory check or completion guarantee; dedicated-cgroup monitoring and external validation of host/container visibility remain necessary.

Provenance now records both the omitted construction network default (unsigned) and explicit signed TOM. Verified WGCNA 1.74 `src/networkFunctions.c:470–471` switches this combination internally to `AdjTypeUnsignedKeepSign`. Analytical arguments remain unchanged; this note describes native handling rather than correcting the selected baseline.

Capacity detection cannot prove that a container namespace exposes every host ancestor; the recorded mount/cgroup evidence needs external review on the execution host. A persistence failure during error capture attempts a separate persistence_failure.txt containing the original error and stack, while retaining the last atomically saved provenance.

### Focused review corrections: hierarchy root and completion semantics

The memory-control reader distinguishes **absent**, **unreadable**, and read values (malformed values parse as unknown). Only an **absent** memory.max at exactly `/sys/fs/cgroup`, after the standard cgroup-v2 mount check passes, is treated as unlimited. Unreadable or malformed root values and absent/unreadable/malformed non-root values remain unknown and fail closed. An explicit finite memory.max at a namespaced visible root is honored. Hidden-ancestor uncertainty remains: the visible mount cannot prove that all host ancestors are exposed.

Applicable current/ancestor **memory.high** values and read states are recorded separately as throttling thresholds. Finite thresholds below 60 GiB and unknown thresholds produce a logged preflight-review flag. They do not change the hard capacity minimum, because memory.high throttles rather than imposing the memory.max hard limit. An unavailable, empty or unresolvable BLAS path fails preflight; the wrapper does not guess a library identity.

`execution_provenance.rds` uses **analysis_status** for the analytical/validation outcome, distinct from overall run completion. Graphics/finalization failures have their own diagnostics; successful analysis status alone never establishes completion. A successfully published **COMPLETED** marker plus verified artifact manifest is required. Provenance is finalized before hashing and is never updated after hashing merely to claim overall completion. A manifest/publication failure may therefore leave completed analysis status with no completion marker.

Ordinary caught analysis failures finalize their partial artifacts and manifest, then propagate failure **outside** the finalization tryCatch. They do not create a misleading finalization_failure.txt after that manifest. Actual finalization failures still receive best-effort diagnostics. Failed completion-marker publication removes its temporary marker (with an external error if cleanup itself fails); no temporary marker is evidence of completion.
