#!/usr/bin/env Rscript
# Baseline only: Original_Manu_Pipe.ipynb, cell 2 (one-based).
# Run from the repository root with its project-local renv active.
# Do not source this file for syntax checks: it runs main() at the end.

fail <- function(message) stop(message, call. = FALSE)

check_ids <- function(ids, label) {
  if (!length(ids) || anyNA(ids) || any(!nzchar(ids)) ||
      any(ids != trimws(ids)) || anyDuplicated(ids)) {
    fail(paste(label, "must be nonempty, unique IDs without surrounding whitespace."))
  }
}

check_labels <- function(values, expected, label) {
  if (anyNA(values) || !setequal(unique(values), expected)) {
    fail(sprintf("%s must contain exactly these labels: %s; observed: %s",
                 label, paste(expected, collapse = ", "),
                 paste(unique(values), collapse = ", ")))
  }
}

sha256 <- function(path) {
  command <- Sys.which("sha256sum")
  if (!nzchar(command)) fail("sha256sum is required to record input provenance.")
  result <- system2(command, shQuote(path), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) fail(paste("SHA-256 failed for", path))
  hash <- substr(result[1], 1, 64)
  if (!grepl("^[0-9a-f]{64}$", hash)) fail(paste("Invalid SHA-256 for", path))
  hash
}

main <- function() {
  root <- normalizePath(getwd())
  if (!file.exists("AGENTS.md") || !file.exists("renv.lock")) {
    fail("Run from the repository root with project-local renv activated.")
  }
  if (!requireNamespace("renv", quietly = TRUE) ||
      !identical(normalizePath(renv::project()), root)) {
    fail("The repository's project-local renv must be activated.")
  }
  if (getRversion() != "4.5.2" || packageVersion("renv") != "1.3.1" ||
      renv::settings$bioconductor.version() != "3.21") {
    fail("Expected reproduction environment: R 4.5.2, renv 1.3.1, Bioconductor 3.21.")
  }
  required <- c("DESeq2", "limma", "dplyr", "ggplot2", "BiocManager", "BiocVersion")
  local_packages <- installed.packages(lib.loc = renv::paths$library())
  if (!all(required %in% rownames(local_packages))) {
    fail("Required preprocessing packages must already be installed in project-local renv.")
  }
  if (as.character(BiocManager::version()) != "3.21") fail("Bioconductor must be 3.21.")

  input_paths <- c(metadata = "Data/Processed/metadata.csv",
                   counts = "Data/Processed/updated_count_matrix (1).csv")
  if (!all(file.exists(input_paths))) fail("Missing baseline input CSV file(s).")
  input_hashes <- vapply(input_paths, sha256, character(1))
  # Inspect original headers before read.csv's default check.names can repair them.
  count_header <- names(read.csv(input_paths[["counts"]], nrows = 0,
                                row.names = NULL, check.names = FALSE))[-1]
  check_ids(count_header, "Count-column sample IDs")
  metadata_header <- names(read.csv(input_paths[["metadata"]], nrows = 0,
                                   row.names = NULL, check.names = FALSE))[-1]
  check_ids(metadata_header, "Metadata column names")

# ─── Chunk 2: Load Data & Metadata ─────────────────────────────────────────────
metadata <- read.csv("Data/Processed/metadata.csv", row.names = 1, header = TRUE)
data_raw  <- read.csv("Data/Processed/updated_count_matrix (1).csv", row.names = 1, header = TRUE)

# Added input validation: fail, never repair unexpected identifiers or values.
check_ids(rownames(metadata), "Metadata sample IDs")
check_ids(colnames(data_raw), "Count-column sample IDs")
check_ids(rownames(data_raw), "Gene IDs")
if (!identical(colnames(data_raw), count_header) ||
    !identical(names(metadata), metadata_header)) {
  fail("CSV loading changed identifiers/column names; refusing silent name repair.")
}
if (!setequal(colnames(data_raw), rownames(metadata))) {
  fail(sprintf("Sample sets differ: counts-only [%s]; metadata-only [%s].",
               paste(setdiff(colnames(data_raw), rownames(metadata)), collapse = ", "),
               paste(setdiff(rownames(metadata), colnames(data_raw)), collapse = ", ")))
}
if (!nrow(data_raw) || !ncol(data_raw) ||
    !all(vapply(data_raw, is.numeric, logical(1)))) {
  fail("Counts must be a nonempty numeric gene-by-sample table.")
}
for (sample in colnames(data_raw)) {
  values <- data_raw[[sample]]
  if (anyNA(values) || any(!is.finite(values)) || any(values < 0) ||
      any(values != floor(values)) || any(values > .Machine$integer.max)) {
    fail(paste("Counts must be finite, nonnegative, integer-valued and within R integer range:", sample))
  }
  if (sum(values) == 0) fail(paste("Count sample has zero library size:", sample))
}
if (!"batch" %in% names(metadata)) fail("Metadata requires batch.")
label_column <- if ("Subtype" %in% names(metadata)) "Subtype" else "category"
if (!label_column %in% names(metadata)) fail("Metadata requires category or Subtype.")
if (all(c("category", "Subtype") %in% names(metadata)) &&
    !identical(metadata$category, metadata$Subtype)) {
  fail("Metadata category and Subtype disagree; refusing an ambiguous label choice.")
}
check_labels(metadata$batch, c("study1", "study2", "study3"), "Input batch")
check_labels(metadata[[label_column]], c("Normal", "ER+", "TNBC", "HER2+"), "Input subtype")

# All generated files are confined to a fresh run directory; never reuse one.
output_base <- "Results/baseline_preprocessing"
output_dir <- file.path(output_base, paste0("run-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", Sys.getpid()))
if (file.exists(output_dir)) fail(paste("Output directory already exists:", output_dir))
if (!dir.create(output_dir, recursive = TRUE)) fail("Cannot create baseline output directory.")
provenance <- list(
  status = "started", started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  source = "notebooks/original/Original_Manu_Pipe.ipynb", source_cell_one_based = 2L,
  input_paths = input_paths, input_sha256 = input_hashes,
  source_sha256 = sha256("notebooks/original/Original_Manu_Pipe.ipynb"),
  script_sha256 = sha256("scripts/baseline/preprocess.R"),
  lockfile_sha256 = sha256("renv.lock"),
  raw_dimensions = dim(data_raw), input_metadata_dimensions = dim(metadata),
  warnings = character(),
  historical_checkpoints_not_reproduced = list(raw_dimensions = c(39376L, 279L),
    retained_genes = 25750L, final_dimensions = c(279L, 25750L)),
  historical_versions = "Unknown; R/Bioconductor releases do not recover package versions.",
  analytical_settings = list(filter = "rowSums(data_raw > 15) > round(0.25 * ncol(data_raw))",
    deseq_design = "~ batch + Subtype", fitting = "DESeq(dds)",
    transformation = "vst(dds, blind = FALSE)",
    batch_design = "model.matrix(~ Subtype, data = metadata)",
    correction = "removeBatchEffect(vsd_mat, batch = metadata$batch, design = design)",
    omitted_arguments = "Source omissions retained; effective defaults belong to this reproduction environment.")
)
log_connection <- file(file.path(output_dir, "execution.log"), open = "wt")
sink(log_connection, split = TRUE)
sink(log_connection, type = "message")
on.exit({
  provenance$finished_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  saveRDS(provenance, file.path(output_dir, "execution_provenance.rds"))
  writeLines(capture.output(str(provenance)), file.path(output_dir, "execution_provenance.txt"))
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
  write.csv(local_packages[, c("Package", "Version", "LibPath"), drop = FALSE],
            file.path(output_dir, "package_versions.csv"), row.names = FALSE)
  sink(type = "message")
  sink()
  close(log_connection)
}, add = TRUE)
cat("Future execution results (not historical saved results). Output:", output_dir, "\n")
withCallingHandlers({

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
if (!nrow(data_filt)) fail("The original filter retained no genes.")
if (!identical(colnames(data_filt), rownames(metadata))) fail("Filtered sample alignment failed.")
provenance$filtered_dimensions <- dim(data_filt)
provenance$retained_genes <- nrow(data_filt)
# Differences are recorded, not silently repaired or forced to match history.
provenance$historical_checkpoint_matches <- list(
  raw_dimensions = identical(dim(data_raw), c(39376L, 279L)),
  retained_genes = nrow(data_filt) == 25750L)
saveRDS(data_filt, file.path(output_dir, "filtered_counts.rds"))

cat("Retained genes:", nrow(data_filt), "of", nrow(data_raw), "\n")

## 2.  Quick QC plot
png(file.path(output_dir, "count_threshold_histogram.png"))
hist(rowSums(data_raw > 15),
     breaks = 50,
     main   = "Genes with count > 15",
     xlab   = "# samples passing threshold")
dev.off()


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

check_labels(as.character(metadata$batch), c("GSE243375", "GSE52194", "GSE58135"), "Recoded batch")
check_labels(as.character(metadata$Subtype), c("Normal", "ERpos", "TNBC", "HER2pos"), "Recoded subtype")
saveRDS(metadata, file.path(output_dir, "aligned_metadata.rds"))
write.csv(metadata, file.path(output_dir, "aligned_metadata.csv"), row.names = TRUE)
provenance$aligned_metadata_dimensions <- dim(metadata)
provenance$batch_subtype_table <- table(metadata$batch, metadata$Subtype)

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
if (!identical(dimnames(assay(vsd)), dimnames(data_filt))) fail("VST changed matrix alignment.")
saveRDS(assay(vsd), file.path(output_dir, "expression_pre_batch.rds"))
provenance$pre_batch_dimensions <- dim(assay(vsd))

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

ggsave(file.path(output_dir, "PCA_pre_batch.png"), pca_pre, width = 8, height = 6, dpi = 300)
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

if (!identical(dimnames(vsd_bc), dimnames(vsd_mat))) fail("Batch correction changed matrix alignment.")
saveRDS(vsd_bc, file.path(output_dir, "expression_post_batch.rds"))
provenance$post_batch_dimensions <- dim(vsd_bc)

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

ggsave(file.path(output_dir, "PCA_post_batch.png"), pca_post, width = 8, height = 6, dpi = 300)
pca_post


# ─── Chunk 7: Reshape for WGCNA ───────────────────────────────────────────────
expr <- t(assay(vsd))
cat("Samples x Genes:", dim(expr), "\n")
head(expr)
if (!identical(rownames(expr), rownames(metadata)) ||
    !identical(colnames(expr), rownames(data_filt))) fail("Final expression alignment failed.")
saveRDS(expr, file.path(output_dir, "expression_samples_by_genes.rds"))
provenance$final_dimensions <- dim(expr)
provenance$historical_checkpoint_matches$final_dimensions <- identical(dim(expr), c(279L, 25750L))
provenance$status <- "completed"
}, warning = function(w) {
  provenance$warnings <<- c(provenance$warnings, conditionMessage(w))
  # Record without suppressing the warning or altering package behavior.
})
invisible(output_dir)
}

main()
