# Original baseline preprocessing through batch correction

This document records source extraction and the baseline implementation described below, not a reproduced result. The implementation has not been run. Scope ends at batch-corrected expression and its transpose; soft-thresholding, WGCNA quality control and network construction are excluded. References use **one-based cell positions in the notebook JSON `cells` array**, counting all cell types; subtract one for the zero-based index. These source cells have null execution counts, so execution numbers cannot identify them or establish execution order.

## Sources and inputs

- `notebooks/original/Original_Manu_Pipe.ipynb`: cell 1 loads packages; cell 2 contains labelled Chunks 2–7, the complete primary candidate below. Cell 3 starts WGCNA soft-threshold selection and is outside scope.
- `notebooks/original/adegbolaayodeji_(Feb_7,_2025,_1_54_58_AM)(1)(1).ipynb` (hereafter February notebook): cell 1 contains the alternative full preprocessing candidate; cell 21 independently reloads the inputs and repeats preprocessing for a later branch. Only its preprocessing is considered here.
- `notebooks/original/Project_RNASeq_BreastCancer.ipynb`: cells 4–9 provide upstream loading context, not the final combined matrix construction.
- `notebooks/original/Untitled7.ipynb`: cells 17–21 provide upstream gene-index checks and cleaning, not a complete route to the final analytical input.

Both R candidates read `/content/metadata.csv` and `/content/updated_count_matrix (1).csv`, with `row.names = 1, header = TRUE`. Their repository counterparts are `Data/Processed/metadata.csv` and `Data/Processed/updated_count_matrix (1).csv`. Relocating paths would be an explicit implementation adaptation. The sample manifest `Data/Manifests/sample_provenance.csv` is project provenance context and is not loaded by these cells.

Current input SHA-256 values (read-only checks, not proof of historical identity):

| File | SHA-256 |
| --- | --- |
| Count matrix | `5e2b722f8f72d8421069e1bbef693389bb863bf7731553e98b3344693c41fd0d` |
| Metadata | `716ede91356d5622d4a3c9ef3004499054ff396bd99674539cbaf2244dd075f6` |

## Primary candidate: Original_Manu_Pipe, cell 2

The following block is the complete verbatim source cell, including diagnostic plots and the terminal transpose. It is documentary code only.

```r
# ─── Chunk 2: Load Data & Metadata ─────────────────────────────────────────────
metadata <- read.csv("/content/metadata.csv", row.names = 1, header = TRUE)
data_raw  <- read.csv("/content/updated_count_matrix (1).csv", row.names = 1, header = TRUE)

# QC check
stopifnot(all(colnames(data_raw) %in% rownames(metadata)))
dim(metadata); dim(data_raw)
head(metadata); head(data_raw)


# ─── Chunk 3 · Re‑order & Filter Counts ────────────────────────────────────────
## 0.  Make sure the sample order in metadata matches the count matrix
metadata <- metadata[colnames(data_raw), ]
stopifnot(all(rownames(metadata) == colnames(data_raw)))   # should be TRUE

## 1.  Filter genes: count > 15 in ≥ 25 % of samples
keep <- rowSums(data_raw > 15) > round(0.25 * ncol(data_raw))
data_filt <- data_raw[keep, ]

cat("Retained genes:", nrow(data_filt), "of", nrow(data_raw), "\n")

## 2.  Quick QC plot
hist(rowSums(data_raw > 15),
     breaks = 50,
     main   = "Genes with count > 15",
     xlab   = "# samples passing threshold")


# ─── Chunk 4 · Metadata Preparation (safe version) ────────────────────────────
# 0.  Ensure column names are syntactically intact (already enforced with check.names = FALSE)

## 1.  If the old 'category' column exists, copy → Subtype
if ("category" %in% names(metadata) && !"Subtype" %in% names(metadata)) {
  metadata$Subtype <- metadata$category
  metadata$category <- NULL
}

## 2.  Map study aliases → true GEO accessions  (no positional tricks)
metadata$batch <- dplyr::recode(metadata$batch,
  "study1" = "GSE52194",
  "study2" = "GSE58135",
  "study3" = "GSE243375"
) |>
  factor(levels = c("GSE243375", "GSE52194", "GSE58135"))

## 3.  Make Subtype values R‑friendly **by value**, not by position
metadata$Subtype <- dplyr::recode(metadata$Subtype,
  "ER+"   = "ERpos",
  "HER2+" = "HER2pos",
  "TNBC"  = "TNBC",
  "Normal"= "Normal"                 # keep same
) |>
  factor(levels = c("Normal", "ERpos", "TNBC", "HER2pos")) |>   # explicit order
  relevel(ref = "Normal")                                        # reference level

## 4.  QC summaries
stopifnot( all(rownames(metadata) == colnames(data_raw)) )       # ordering
print(str(metadata))
print(table(metadata$batch, metadata$Subtype))                   # should match expectations


# ───────────────────────── Chunk 5 · DESeq2 Normalisation & VST ─────────────────────────
suppressPackageStartupMessages(library(DESeq2))

## 1.  Build DESeq2 object
dds <- DESeqDataSetFromMatrix(
  countData = data_filt,
  colData   = metadata,
  design    = ~ batch + Subtype          # batch first, biology second
)

## 2.  Run DESeq() (size‑factor & dispersion estimation + NB fitting)
dds <- DESeq(dds)

## 3.  Variance‑stabilising transformation (blind = FALSE ⇒ respects design)
vsd <- vst(dds, blind = FALSE)

## 4.  Quick numeric sanity check
print(summary(as.vector(assay(vsd))), max = 6)

## 5.  PCA plot before batch correction
pca_df      <- plotPCA(vsd, intgroup = c("batch", "Subtype"), returnData = TRUE)
percentVar  <- round(100 * attr(pca_df, "percentVar"))

library(ggplot2)
pca_pre     <- ggplot(pca_df,
                      aes(PC1, PC2, colour = Subtype, shape = batch)) +
  geom_point(size = 3) +
  xlab(sprintf("PC1: %s%%", percentVar[1])) +
  ylab(sprintf("PC2: %s%%", percentVar[2])) +
  ggtitle("(A) PCA – raw VST counts") +
  theme_minimal()

ggsave("PCA_pre_batch.png", pca_pre, width = 8, height = 6, dpi = 300)
pca_pre        # prints in notebook


# ───────────────────────── Chunk 6 · Batch‑Effect Removal ─────────────────────────
suppressPackageStartupMessages(library(limma))

## 1.  Extract VST counts & build design to preserve biology
vsd_mat <- assay(vsd)
design  <- model.matrix(~ Subtype, data = metadata)   # keep Subtype signal

## 2.  Remove batch effect
vsd_bc  <- removeBatchEffect(vsd_mat,
                             batch  = metadata$batch,
                             design = design)

## 3.  Slot corrected counts back into vsd object
assay(vsd) <- vsd_bc        # drop‑in replacement for downstream chunks

## 4.  PCA after batch correction
pca_df_bc     <- plotPCA(vsd, intgroup = c("batch", "Subtype"), returnData = TRUE)
percentVar_bc <- round(100 * attr(pca_df_bc, "percentVar"))

pca_post <- ggplot(pca_df_bc,
                   aes(PC1, PC2, colour = Subtype, shape = batch)) +
  geom_point(size = 3) +
  xlab(sprintf("PC1: %s%%", percentVar_bc[1])) +
  ylab(sprintf("PC2: %s%%", percentVar_bc[2])) +
  ggtitle("(B) PCA – batch‑corrected VST counts") +
  theme_minimal()

ggsave("PCA_post_batch.png", pca_post, width = 8, height = 6, dpi = 300)
pca_post


# ─── Chunk 7: Reshape for WGCNA ───────────────────────────────────────────────
expr <- t(assay(vsd))
cat("Samples x Genes:", dim(expr), "\n")
head(expr)
```

### Alignment and exact settings

Count rows are gene identifiers; count columns and metadata row names are sample identifiers. The first assertion checks membership only. The primary candidate then explicitly subsets/reorders metadata to count-column order and checks equality twice. It does not join or reorder genes, map gene identifiers, deduplicate them, validate integer/nonnegative counts, check sample uniqueness, or explicitly check missing values. Filtering subsets rows in their existing order. `assay(vsd)` remains genes × samples; the final transpose makes samples × genes without an additional sorting step.

The exact filter is `rowSums(data_raw > 15) > round(0.25 * ncol(data_raw))`. Both comparisons are strict. For the saved 279-sample input, `round(0.25 * 279)` is 70, so at least 71 samples must have counts greater than 15. The comment's “≥ 25%” wording is less precise than the executable expression. `na.rm` is omitted from `rowSums`; no missing-value handling is added.

Metadata handling is conditional: `category` is copied to `Subtype` and removed only if `category` exists and `Subtype` does not. Batch alias mapping and factor levels, subtype value recoding, and the `Normal` reference are exactly as shown above. The comment claiming `check.names = FALSE` was already enforced is inconsistent with the displayed `read.csv` calls: neither supplies that argument. Preserve the calls and record this discrepancy.

| Operation | Explicit settings | Omitted settings retained as defaults |
| --- | --- | --- |
| CSV loading | `row.names = 1`, `header = TRUE` | `check.names`, `stringsAsFactors` and all other read arguments are omitted. |
| DESeq2 construction | `countData = data_filt`, `colData = metadata`, `design = ~ batch + Subtype` | No additional constructor settings. |
| Fitting | `DESeq(dds)` | All fitting options omitted, including `test`, `fitType`, `sfType`, `betaPrior`, `minReplicatesForReplace`, `useT`, `minmu`, `parallel` and `BPPARAM`. No separate size-factor call, custom normalization factors, or explicit test contrast. |
| Transformation | `vst(dds, blind = FALSE)` | `nsub`, `fitType` and other arguments omitted; this is `vst`, not a substituted `varianceStabilizingTransformation` call. |
| Biological design | `model.matrix(~ Subtype, data = metadata)` | Formula includes an intercept; contrast options are not set in the cell. |
| Batch removal | `removeBatchEffect(vsd_mat, batch = metadata$batch, design = design)` | `batch2`, `covariates`, `weights` and any further fitting arguments omitted. No ComBat, clipping, rescaling or rounding. |
| PCA diagnostics | `intgroup = c("batch", "Subtype")`, `returnData = TRUE` | `ntop` omitted; saved messages report 500. |

Omitted arguments must remain omitted for faithful source reproduction. Their effective historical values are package/version dependent and are not fully established by the notebooks. The saved fitting log specifically reports `minReplicatesForReplace = 7`; that is an observed historical default, not an explicitly supplied parameter. No complete historical package lockfile or session information is established by these inspected cells. The current renv environment records a new reproduction environment, not these historical versions.

## Alternative candidate: February notebook, cell 1

The verbatim computational segment below starts after the package installation/loading lines and ends before the next cell's WGCNA code.

```r
# Load Data and Metadata
metadata <- read.csv("/content/metadata.csv", row.names = 1, header = TRUE)
data <- read.csv("/content/updated_count_matrix (1).csv", row.names = 1, header = TRUE)

# Ensure Column Names in Count Matrix Match Sample IDs in Metadata
stopifnot(all(colnames(data) %in% rownames(metadata)))  # Will stop if not TRUE

# Filter Genes Based on Counts > 15 in at least 25% of Samples
data <- data[rowSums(data > 15) > round(0.25 * ncol(data)), ]
cat("Number of genes retained after filtering:", nrow(data), "\n")

# Prepare Metadata
metadata$batch <- as.factor(metadata$batch)
metadata$category <- as.factor(metadata$category)

# Set Reference Level for "category"
metadata$category <- relevel(metadata$category, ref = "Normal")

# Create DESeq2 Object and Perform Normalization
dds <- DESeqDataSetFromMatrix(countData = data, colData = metadata, design = ~ batch + category)
dds <- DESeq(dds)

# Apply Variance-Stabilizing Transformation (VST)
vsd <- vst(dds, blind = FALSE)

# Batch Correction Using limma's removeBatchEffect
vsd_counts <- assay(vsd)  # Extract VST-transformed counts
design_matrix <- model.matrix(~ category, data = metadata)  # Design matrix to preserve category effect
assay(vsd) <- removeBatchEffect(vsd_counts, batch = metadata$batch, design = design_matrix)

# Extract Final Processed Data for WGCNA
data <- assay(vsd)  # Final normalized, batch-corrected data
data <- t(data)  # Transpose: Rows = Samples, Columns = Genes (required for WGCNA)

# Check the Processed Data
cat("Processed data dimensions (samples x genes):", dim(data), "\n")
head(data)
```

Cell 1 uses the same strict filter, `DESeq(dds)`, and `vst(dds, blind = FALSE)`. It uses `~ batch + category` and preserves `~ category` in batch removal. It checks sample membership but **does not explicitly reorder metadata or assert equality of its order to the count columns**. It uses `as.factor` for batch/category and relevels only category to `Normal`; it does not recode labels or specify the complete factor level order. DESeq2 constructor behavior must not be mistaken for an explicit source alignment step.

February cell 21 again loads the same CSVs, checks membership, applies the same filter, constructs `design = ~ batch + category`, calls `DESeq(dds)` and `vst(dds, blind = FALSE)`, and uses `model.matrix(~ category, data = metadata)`. It then calls exactly:

```r
batch_corrected_data <- removeBatchEffect(vsd_counts, batch = metadata$batch, design = design_matrix)
```

Unlike cell 1, cell 21 contains no explicit `as.factor` or `relevel` metadata preparation and leaves corrected data in a separate gene × sample matrix; it does not replace `assay(vsd)` or transpose it. Its saved class output is `"matrix" "array"`. These differences must not be silently folded into cell 1 or the primary candidate.

## Required packages confined to this stage

- **DESeq2**: dataset construction, fitting, VST and the primary candidate's PCA diagnostics; its dependencies include the assay infrastructure from **SummarizedExperiment**.
- **limma**: `removeBatchEffect`.
- **dplyr**: the primary candidate calls `dplyr::recode` directly but its cell 1 does not explicitly install dplyr. The February preprocessing candidates do not call it.
- **ggplot2**: explicitly attached in the primary candidate for pre/post PCA plots and PNG exports. The February preprocessing segments do not create these plots.
- Base R, **utils** (`read.csv`) and **stats** (`model.matrix`, factor contrasts) supply the remaining operations; transitive dependencies of the packages above would also be needed.

**BiocManager** is used by the original setup cells for package installation, not for expression computation. They also install/load **WGCNA**, **impute**, **preprocessCore**, **GO.db**, and **AnnotationDbi** for the wider notebook. No calls to those packages are required to compute the preprocessing endpoint described here, apart from dependencies pulled in by the stage packages themselves. The primary setup also enables WGCNA threads and binds `cor <- WGCNA::cor`; these are network setup, not preprocessing steps. No package was installed for this documentation task.

## Upstream provenance gaps

`Project_RNASeq_BreastCancer.ipynb` cell 4 lists four raw TSVs under `/content/drive/MyDrive/Project_RNASeq_BreastCancer/`: `GSE243375_raw_counts_GRCh38.p13_NCBI.tsv`, `GSE263089_raw_counts_GRCh38.p13_NCBI.tsv`, `GSE52194_raw_counts_GRCh38.p13_NCBI (1).tsv`, and `GSE58135_raw_counts_GRCh38.p13_NCBI.tsv`. Cells 5–7 assign `study1`, `study2`, `study3`, `study4` in that order, read with pandas `sep='\t', index_col=0`, prepend a `Study` row and collect dataframes. Cell 7 resets that list and attempts subtype insertion with `if study_label == 'Study3'`; the supplied labels are lowercase `study3`, so the condition does not match. Cell 8 repeats the same case-mismatched condition outside the loop. The source explicitly says the dataframes are not merged yet. This alias mapping differs from the final R metadata recoding and cannot be substituted for it. The established final metadata has no GSE263089 samples; these cells do not document a final exclusion reason.

`Untitled7.ipynb` cells 17–21 read `/content/GSE52194_preprocessed1.tsv`, `/content/GSE58135_preprocessed.tsv` and `/content/GSE243375_preprocessed(1).tsv` (later the cleaned GSE243375 file), using pandas `sep='\t', index_col=0`. Cell 18 compares string-converted indices with `.equals` (order-sensitive), then reports set differences. Cell 19 cleans GSE243375 via `.astype(str)` followed by `.str.replace(r'\.0$', '', regex=True).str.strip()` and writes `GSE243375_preprocessed_cleaned.tsv`. Cell 20 reloads that file without applying the same string conversion. Cell 21 applies the cleaning to all three inputs and writes `GSE52194_preprocessed_cleaned.tsv`, `GSE58135_preprocessed_cleaned.tsv`, and `GSE243375_preprocessed_cleaned_v2.tsv`. Saved comparisons still report unequal indices, ending with differences `['89887', 'nan']`. Mixed-type warnings and metadata-like rows (`Study`, `Subtype`, `Sample_Type`, `Batch`) are visible in saved output. These are unresolved gene alignment checks, not evidence of a successful merge. No mapping from these numeric identifiers to the final symbol-like gene rows is supplied here. Gene-annotation provenance remains unresolved.

## Historical checkpoints (saved notebook outputs only)

None of the following were newly reproduced. Matching displayed values do not prove identical full matrices or establish which notebook produced a historical file.

| Source | Saved checkpoint |
| --- | --- |
| Primary cell 2, Chunk 2 | Metadata: 279 × 2; raw counts: 39,376 genes × 279 samples. |
| Primary cell 2, Chunk 3 | `Retained genes: 25750 of 39376`. |
| Primary cell 2, Chunk 4 | Batch/subtype table below; metadata remains 279 rows and two columns. |
| Primary cell 2, Chunk 5 | Outlier replacement/refitting for 1,107 genes; reported `minReplicatesForReplace = 7`. VST summary: Min 1.671, Q1 5.313, Median 7.614, Mean 7.137, Q3 9.012, Max 23.421 (before batch removal). |
| Primary cell 2, Chunks 5–6 | Two PCA messages report `ntop=500`; code saves `PCA_pre_batch.png` and `PCA_post_batch.png` with width 8, height 6, dpi 300, units omitted. Saved plots are historical diagnostics. |
| Primary cell 2, Chunk 7 | `Samples x Genes: 279 25750`; first sample/gene displayed corrected value: GSM1401790 / DDX11L1 = 5.011149; GSM1401790 / WASH7P = 8.288473. |
| February cell 1 | 25,750 retained genes; 1,107 genes refitted with reported replacement threshold 7; `Processed data dimensions (samples x genes): 279 25750`. The displayed first sample/gene values match those above at printed precision. |
| February cell 21 | 25,750 retained genes; corrected object class `matrix`, `array`; no explicit dimension checkpoint. |
| Primary cell 1 setup log | R 4.5.1 (2025-06-13), Bioconductor 3.21, BiocManager 1.30.26. |
| February cells 1 and 21 setup logs | R 4.4.2 (2024-10-31), Bioconductor 3.20, BiocManager 1.30.25. |

Saved primary batch/subtype table:

| Batch | Normal | ERpos | TNBC | HER2pos |
| --- | ---: | ---: | ---: | ---: |
| GSE243375 | 0 | 0 | 0 | 158 |
| GSE52194 | 0 | 0 | 6 | 5 |
| GSE58135 | 26 | 42 | 42 | 0 |

The source does not save a dedicated batch-corrected expression artifact in these preprocessing cells; its endpoint is an in-memory object. Later notebook exports are outside this bounded extraction.

## Selected baseline and implementation adaptations

The project has selected **`Original_Manu_Pipe.ipynb` cell 2 (one-based)** as the baseline preprocessing source. The rationale is that the current inputs are compatible, the saved checkpoints match this cell, and downstream cells use its outputs. The February notebook variants remain documented for comparison, not as pending source choices. Do not create a hybrid by borrowing alignment, factor preparation or plotting from them.

The analytical source is preserved; file-location adaptations are:

- Replace `/content/metadata.csv` with `Data/Processed/metadata.csv` and `/content/updated_count_matrix (1).csv` with `Data/Processed/updated_count_matrix (1).csv`.
- Redirect `PCA_pre_batch.png` and `PCA_post_batch.png` to a separate baseline output directory, such as `Results/baseline_preprocessing/`, without overwriting historical outputs.

The implementation preserves the selected cell's analytical calls, parameter values and omitted defaults, including the PCA export settings. The verbatim source block above retains the original paths; the script applies these file-location adaptations and adds the validation and recording described below.

Historical package versions remain unknown. R and Bioconductor release information alone does not recover the installed package versions or their effective defaults. A run in the new renv environment must be described as a new reproduction environment, not exact historical software reconstruction.

Dataset and analytical label are strongly confounded in the saved table. Neither DESeq2 design nor batch removal includes patient IDs; batch correction does not establish independent samples or independent validation. These issues are recorded without altering the baseline or introducing methodological corrections. Upstream annotation/merge gaps need separate scope if reconstruction from raw inputs is requested; they do not justify inventing processing steps when starting from the established processed CSVs.

## Implemented script (not yet executed)

`scripts/baseline/preprocess.R` implements selected cell 2. When execution is separately authorized, run `Rscript scripts/baseline/preprocess.R` from the repository root with renv activated. Do not source the script for syntax checking: its final `main()` call starts preprocessing. It requires the already installed project-local packages, R 4.5.2, renv 1.3.1 and Bioconductor 3.21; it never installs packages.

Added validation rejects empty/duplicate sample or gene IDs, unequal sample sets, silent CSV header repair, nonnumeric/missing/nonfinite/negative/fractional/out-of-integer-range counts, zero sample library sizes, missing metadata fields, ambiguous category/Subtype values and unexpected labels. Gene IDs and metadata sample IDs are checked for whitespace padding, but `read.csv` strips whitespace from count-column headers before validation, so padded count headers are not reliably rejected. Input batches must contain exactly `study1`, `study2`, `study3`; input subtype labels must contain exactly `Normal`, `ER+`, `TNBC`, `HER2+`. The original conditional rename, alias recoding, factor levels, metadata reordering and filtering remain intact. Checks after recoding and at matrix boundaries ensure no identifiers or orientation were changed unexpectedly. Validation itself does not trim, round, impute, relabel or discard unexpected inputs.

Each execution creates a fresh `Results/baseline_preprocessing/run-<UTC timestamp>-<PID>/` directory and refuses to reuse an existing one. The entire output tree is ignored by Git. All generated files, including the original histogram adapted to an explicit PNG device, stay inside that directory:

| Output | Content/orientation |
| --- | --- |
| `filtered_counts.rds` | Original filtered count data frame, genes × samples; no DESeq2 outlier replacements substituted. |
| `aligned_metadata.rds`, `aligned_metadata.csv` | Aligned and recoded metadata; RDS preserves factor levels. |
| `expression_pre_batch.rds` | VST expression before batch removal, genes × samples. |
| `expression_post_batch.rds` | Batch-corrected VST expression, genes × samples. |
| `expression_samples_by_genes.rds` | Final `expr`, samples × genes. |
| `PCA_pre_batch.png`, `PCA_post_batch.png` | Original PCA calls, plots and export settings; destinations redirected. |
| `count_threshold_histogram.png` | Original count-threshold histogram; explicit device prevents a repository-root `Rplots.pdf`. |
| `execution_provenance.rds`, `execution_provenance.txt` | Input paths/SHA-256, notebook/script/lockfile SHA-256, analytical settings, execution dimensions, retained-gene count, batch/subtype table, timestamps, completion status and captured warnings. The RDS retains the full captured warning text; the text summary may truncate it. |
| `sessionInfo.txt`, `package_versions.csv`, `execution.log` | Session information, installed project-library package versions/paths, and runtime diagnostics/messages. The log does not reliably contain warnings emitted after it is closed. |

SHA-256 recording requires the existing `sha256sum` command; absence is a clear failure, not a fallback to another hash. Provenance records are written on exit once the validated run directory exists, including on an incomplete analysis; only `status = "completed"` establishes successful completion. Earlier validation failures create no run directory. Historical dimensions and retained-gene checkpoints are explicitly stored under `historical_checkpoints_not_reproduced`, with comparisons recorded separately; discrepancies are not silently corrected or forced to match history. No future execution results are asserted in this document.

The environment verification reviewed this import warning: `replacing previous import ‘S4Arrays::makeNindexFromArrayViewport’ by ‘DelayedArray::makeNindexFromArrayViewport’ when loading ‘SummarizedExperiment’`. Package loading succeeded; this does not establish that preprocessing succeeds. The script records warnings without suppressing them or changing package behavior. Historical package versions remain unknown despite the logged R/Bioconductor releases; the lockfile identifies newly locked reproduction versions only.
