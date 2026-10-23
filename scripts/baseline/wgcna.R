#!/usr/bin/env Rscript
# Faithful baseline only. Run in a fresh Rscript process from the repository root.
# Parse this file for syntax checks; NEVER source it for verification.
fail <- function(message) stop(message, call. = FALSE)
check_ids <- function(x, label) {
  if (!length(x) || anyNA(x) || any(!nzchar(x)) || any(x != trimws(x)) || anyDuplicated(x))
    fail(paste("Invalid identifiers:", label))
}
sha256 <- function(path) {
  command <- Sys.which("sha256sum")
  if (!nzchar(command)) fail("sha256sum is required.")
  result <- system2(command, shQuote(path), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status")) || !length(result) ||
      !grepl("^[0-9a-f]{64} ", result[1])) fail(paste("SHA-256 failed:", path))
  substr(result[1], 1, 64)
}
# Small, side-effect-free parsing helpers also permit standalone capacity fixtures.
read_memory_control <- function(path) {
  # Lack of directory search permission cannot establish absence.
  if (file.access(dirname(path), 5L) != 0L)
    return(list(state = "unreadable", value = character()))
  if (!file.exists(path)) return(list(state = "absent", value = character()))
  if (file.access(path, 4L) != 0L) return(list(state = "unreadable", value = character()))
  tryCatch(list(state = "read", value = readLines(path, warn = FALSE)),
    warning = function(w) list(state = "unreadable", value = character(), message = conditionMessage(w)),
    error = function(e) list(state = "unreadable", value = character(), message = conditionMessage(e)))
}
parse_memory_control <- function(record, directory, standard_mount) {
  # Only absence at the verified standard root is the normal unlimited-root case.
  if (identical(record$state, "absent") && identical(directory, "/sys/fs/cgroup") && standard_mount)
    return(Inf)
  if (!identical(record$state, "read") || length(record$value) != 1L) return(NA_real_)
  if (record$value == "max") return(Inf)
  if (!grepl("^[0-9]+$", record$value)) return(NA_real_)
  value <- as.numeric(record$value)
  if (!is.finite(value) || value < 0) return(NA_real_)
  value
}
assess_memory_capacity <- function(guest_bytes, controls, standard_mount, safe_cgroup,
                                   minimum_bytes = 60 * 2^30) {
  limits <- vapply(names(controls), function(directory)
    parse_memory_control(controls[[directory]]$max, directory, standard_mount), numeric(1))
  high <- vapply(names(controls), function(directory)
    parse_memory_control(controls[[directory]]$high, directory, standard_mount), numeric(1))
  known <- is.finite(guest_bytes) && guest_bytes > 0 && standard_mount && safe_cgroup &&
    "/sys/fs/cgroup" %in% names(controls) && length(limits) > 0L && !anyNA(limits)
  effective <- if (known) min(guest_bytes, limits) else NA_real_
  list(minimum_bytes = minimum_bytes, guest_bytes = guest_bytes, controls = controls,
    cgroup_limits_bytes = limits, effective_bytes = effective,
    status = if (!known) "unknown" else if (effective >= minimum_bytes) "accepted" else "insufficient",
    # memory.high is a throttle threshold; it never participates in hard capacity.
    throttling = list(memory_high_bytes = high,
      low_directories = names(high)[which(!is.na(high) & high < minimum_bytes)],
      unknown_directories = names(high)[which(is.na(high))]))
}
main <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)
  if (interactive() || !any(grepl("^--file=", commandArgs())))
    fail("Use a fresh Rscript process, not source() or an interactive session.")
  if (!file.exists("AGENTS.md") || !file.exists("renv.lock")) fail("Run from repository root.")
  if (!requireNamespace("renv", quietly = TRUE) ||
      !identical(normalizePath(renv::project()), root)) fail("Activate project-local renv.")
  # Fresh function scope prevents stale moduleColors and notebook state reuse.
  git <- function(args) {
    value <- system2("git", args, stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(value, "status"))) fail(paste("Git inspection failed:", paste(args, collapse = " ")))
    value
  }
  repository <- list(branch = git(c("branch", "--show-current")),
                     head = git(c("rev-parse", "HEAD")),
                     status = git(c("status", "--porcelain=v1")),
                     diff = git(c("diff", "--stat")))
  if (!identical(repository$branch, "analysis/initial-review") || length(repository$status))
    fail("Execution requires analysis/initial-review and a clean tree; commit/review implementation separately.")
  output_base <- file.path(root, "Results/baseline_wgcna")
  if (!dir.exists(output_base) && !dir.create(output_base, recursive = TRUE)) fail("Cannot create output base.")
  output_dir <- file.path(output_base, paste0("run-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", Sys.getpid()))
  if (file.exists(output_dir) || !dir.create(output_dir)) fail("Run directory exists or cannot be created.")
  setwd(output_dir)
  on.exit(setwd(root), add = TRUE)
  utc <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
  provenance <- list(analysis_status = "started", started_utc = utc(), repository = repository,
                     stages = list(), warnings = list(), errors = list(),
                     source_cells = c(1L, 3L, 5L, 6L, 9L, 10L, 13L, 15L, 16L, 47L),
                     historical_versions = "Unknown; locked versions describe reproduction only.")
  persist <- function() {
    # Each replacement is atomic on the same filesystem; RDS is authoritative.
    # Leave a failed temporary write in place for diagnosis; never replace the last good record.
    atomic_write <- function(path, writer) {
      temporary <- tempfile(pattern = paste0(".", path, "-"), tmpdir = ".")
      writer(temporary)
      if (!file.rename(temporary, path)) fail(paste("Atomic provenance rename failed:", temporary, path))
    }
    atomic_write("execution_provenance.rds", function(path) saveRDS(provenance, path))
    atomic_write("execution_provenance.txt", function(path)
      writeLines(capture.output(str(provenance)), path))
  }
  log_connection <- file("execution.log", "wt")
  sink(log_connection, split = TRUE)
  sink(log_connection, type = "message")
  on.exit({ sink(type = "message"); sink(); close(log_connection) }, add = TRUE)
  stage <- function(name, state = "started") {
    provenance$current_stage <<- name
    provenance$stages[[length(provenance$stages) + 1L]] <<- list(stage = name, state = state, utc = utc())
    cat("STAGE", name, state, utc(), "\n")
    flush(log_connection)
    persist()
  }
  manifest <- function() {
    paths <- sort(list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE))
    paths <- paths[!file.info(paths)$isdir & !paths %in% c("artifact_checksums.csv", "COMPLETED")]
    hashes <- vapply(paths, sha256, character(1))
    write.csv(data.frame(path = paths, bytes = file.info(paths)$size, sha256 = hashes),
              "artifact_checksums.csv", row.names = FALSE)
    if (!identical(vapply(paths, sha256, character(1)), hashes)) fail("Artifact checksum verification failed.")
    sha256("artifact_checksums.csv")
  }
  tryCatch(withCallingHandlers({
    stage("input_and_environment")
    lock_path <- file.path(root, "renv.lock")
    lock <- renv::lockfile_read(lock_path)
    local_library <- renv::paths$library(project = root)
    installed <- installed.packages(lib.loc = local_library)
    expected <- vapply(lock$Packages, function(x) x$Version, character(1))
    if (as.character(getRversion()) != lock$R$Version ||
        renv::settings$bioconductor.version() != lock$Bioconductor$Version ||
        !all(names(expected) %in% rownames(installed)) ||
        !identical(unname(installed[names(expected), "Version"]), unname(expected)))
      fail("Restore the locked R/Bioconductor/project library before execution.")
    for (pkg in names(expected)) {
      if (!identical(normalizePath(find.package(pkg)), normalizePath(file.path(local_library, pkg))))
        fail(paste("Package resolves outside project library:", pkg))
    }
    write.csv(installed[, c("Package", "Version", "LibPath"), drop = FALSE], "package_versions.csv", row.names = FALSE)
    input_base <- file.path(root, "Results/baseline_preprocessing/run-20261013T053229Z-205981")
    input_paths <- file.path(input_base, c("expression_samples_by_genes.rds", "aligned_metadata.rds", "execution_provenance.rds"))
    names(input_paths) <- c("expression", "metadata", "preprocessing_provenance")
    expected_hashes <- c(expression = "c5d30758d2fdad1bbb980845958e61370c7a67592130f6e41b4ec0837449b3b4",
                         metadata = "c6b766098f7d4dea34e60fa7b7167994f4845d983f5a57366547713a77a04644",
                         preprocessing_provenance = "10bae632b4abd190267bd960640d265ece960b5616841aca65de213ced20f9c7")
    if (!all(file.exists(input_paths))) fail("Missing reviewed preprocessing inputs/provenance.")
    observed_hashes <- vapply(input_paths, sha256, character(1))
    provenance$inputs <- list(paths = input_paths, expected_sha256 = expected_hashes, observed_sha256 = observed_hashes)
    persist()
    if (!identical(observed_hashes, expected_hashes)) fail("Reviewed preprocessing checksum mismatch.")
    upstream <- readRDS(input_paths[["preprocessing_provenance"]])
    if (!identical(upstream$status, "completed")) fail("Preprocessing provenance is incomplete.")
    provenance$preprocessing <- upstream
    expr <- readRDS(input_paths[["expression"]])
    metadata <- readRDS(input_paths[["metadata"]])
    if (!is.matrix(expr) || !is.numeric(expr) || !identical(dim(expr), c(279L, 25750L)) ||
        any(!is.finite(expr)) || !is.data.frame(metadata) || !identical(dim(metadata), c(279L, 2L)))
      fail("Unexpected expression/metadata dimensions, type or nonfinite values.")
    check_ids(rownames(expr), "expression samples")
    check_ids(colnames(expr), "expression genes")
    check_ids(rownames(metadata), "metadata samples")
    check_ids(names(metadata), "metadata columns")
    if (!identical(rownames(expr), rownames(metadata))) fail("Sample order differs; no reordering permitted.")
    for (field in c("batch", "Subtype")) {
      levels_expected <- if (field == "batch") c("GSE243375", "GSE52194", "GSE58135") else c("Normal", "ERpos", "TNBC", "HER2pos")
      if (!is.factor(metadata[[field]]) || is.ordered(metadata[[field]]) ||
          !identical(levels(metadata[[field]]), levels_expected) || anyNA(metadata[[field]]) ||
          !setequal(as.character(metadata[[field]]), levels_expected)) fail(paste("Invalid factor:", field))
    }
    provenance$input_validation <- list(dimensions = dim(expr), metadata_dimensions = dim(metadata),
      samples = rownames(expr), genes = colnames(expr), factor_levels = lapply(metadata[c("batch", "Subtype")], levels))
    provenance$file_sha256 <- vapply(file.path(root, c("renv.lock", "scripts/baseline/wgcna.R",
      "notebooks/original/Original_Manu_Pipe.ipynb", "docs/baseline_wgcna.md")), sha256, character(1))
    read_optional <- function(path) if (file.exists(path)) readLines(path, warn = FALSE) else "unavailable"
    provenance$cpu <- list(logical = parallel::detectCores(), physical = parallel::detectCores(logical = FALSE),
      proc_status = read_optional("/proc/self/status"), proc_cgroup = read_optional("/proc/self/cgroup"),
      lscpu = if (nzchar(Sys.which("lscpu"))) system2("lscpu", stdout = TRUE, stderr = TRUE) else "unavailable")
    # Record the current cgroup and ancestors: quotas can be imposed above the leaf.
    cg <- read_optional("/proc/self/cgroup")
    cg2 <- sub("^0::", "", cg[grepl("^0::", cg)])
    provenance$cgroups <- list()
    memory_controls <- list()
    if (length(cg2) == 1L) {
      cg_dir <- sub("/+$", "", file.path("/sys/fs/cgroup", sub("^/", "", cg2)))
      while (startsWith(cg_dir, "/sys/fs/cgroup")) {
        provenance$cgroups[[cg_dir]] <- lapply(setNames(c("cpu.max", "cpuset.cpus.effective", "memory.max",
          "memory.current", "memory.peak", "memory.events"), c("cpu.max", "cpuset.cpus.effective", "memory.max",
          "memory.current", "memory.peak", "memory.events")), function(f) read_optional(file.path(cg_dir, f)))
        memory_controls[[cg_dir]] <- list(max = read_memory_control(file.path(cg_dir, "memory.max")),
          high = read_memory_control(file.path(cg_dir, "memory.high")))
        if (cg_dir == "/sys/fs/cgroup") break
        cg_dir <- dirname(cg_dir)
      }
    }
    blas_path <- unname(extSoftVersion()["BLAS"])
    if (length(blas_path) != 1L || is.na(blas_path) || !nzchar(blas_path))
      fail("BLAS path is unavailable; verify the numerical library before execution.")
    provenance$numerical_libraries <- list(software = extSoftVersion(), lapack = La_library(),
      blas_resolved_path = normalizePath(blas_path, mustWork = TRUE))
    provenance$contrasts <- getOption("contrasts")
    # Capacity safeguard only; swap is deliberately excluded. Unknown layouts fail closed.
    meminfo <- read_optional("/proc/meminfo")
    memtotal <- grep("^MemTotal:[[:space:]]+[0-9]+[[:space:]]+kB$", meminfo, value = TRUE)
    guest_bytes <- if (length(memtotal) == 1L)
      as.numeric(sub("^MemTotal:[[:space:]]+([0-9]+)[[:space:]]+kB$", "\\1", memtotal)) * 1024 else NA_real_
    capacity <- list(minimum_bytes = 60 * 2^30, guest_bytes = guest_bytes,
      proc_cgroup = cg, mountinfo = read_optional("/proc/self/mountinfo"),
      effective_bytes = NA_real_, status = "unknown")
    provenance$memory_capacity <- capacity
    persist()
    # Require the standard unified cgroup-v2 mount with a visible hierarchy root.
    # Hidden ancestor limits, v1/hybrid hierarchies, traversal paths and unreadable limits
    # cannot establish capacity and must be reviewed externally rather than assumed unlimited.
    mounts <- grep(" - cgroup2 ", capacity$mountinfo, value = TRUE)
    standard_mount <- any(vapply(strsplit(mounts, " +"), function(fields)
      length(fields) >= 6L && fields[4] == "/" && fields[5] == "/sys/fs/cgroup", logical(1)))
    safe_cgroup <- length(cg) == 1L && length(cg2) == 1L && startsWith(cg2, "/") &&
      !any(strsplit(cg2, "/", fixed = TRUE)[[1]] %in% c(".", ".."))
    assessed <- assess_memory_capacity(guest_bytes, memory_controls, standard_mount, safe_cgroup)
    capacity <- c(assessed, capacity[c("proc_cgroup", "mountinfo")])
    provenance$memory_capacity <- capacity
    cat("MEMORY CAPACITY status:", capacity$status, "guest GiB:", guest_bytes / 2^30,
        "effective GiB:", capacity$effective_bytes / 2^30, "minimum GiB: 60\n")
    if (length(capacity$throttling$low_directories) || length(capacity$throttling$unknown_directories))
      cat("PREFLIGHT REVIEW: memory.high throttling thresholds below 60 GiB or unknown; inspect provenance:",
        paste(c(capacity$throttling$low_directories, capacity$throttling$unknown_directories), collapse = ", "), "\n")
    flush(log_connection)
    persist()
    if (!identical(capacity$status, "accepted"))
      fail("Unknown or insufficient effective RAM capacity; require at least 60 GiB, excluding swap.")
    stage("input_and_environment", "finished")

    stage("Manu_cell_1")
# BEGIN MANU CELL 1 (installation statements excluded)
library(DESeq2)
library(limma)

library(WGCNA)          # 1. attach WGCNA *last*
enableWGCNAThreads()    # 2. optional speed-up
cor <- WGCNA::cor       # 3. guarantee the fast correlation is used
# END MANU CELL 1

    thread_vars <- c("ALLOW_WGCNA_THREADS", "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
      "GOTO_NUM_THREADS", "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "RCPP_PARALLEL_NUM_THREADS")
    provenance$threads <- list(effective_wgcna = WGCNA::WGCNAnThreads(), environment = Sys.getenv(thread_vars, unset = NA))
    functions <- c("pickSoftThreshold", "blockwiseModules", "adjacency", "intramodularConnectivity",
      "signedKME", "orderMEs", "cor", "enableWGCNAThreads", "moduleEigengenes", "mergeCloseModules")
    defaults <- setNames(lapply(functions, function(n) formals(get(n, asNamespace("WGCNA")))), functions)
    saveRDS(defaults, "effective_function_formals.rds")
    writeLines(capture.output(print(defaults)), "effective_function_formals.txt")
    provenance$effective_settings <- list(threshold_block_size = WGCNA::blockSize(ncol(expr),
      rectangularBlocks = TRUE, maxMemoryAllocation = 2^30), construction_max_block = 26000L,
      construction_network_type = formals(WGCNA::blockwiseModules)$networkType,
      construction_TOM_type = "signed",
      native_adjacency_handling = paste("WGCNA 1.74 src/networkFunctions.c:470-471:",
        "unsigned construction with signed TOM switches internally to AdjTypeUnsignedKeepSign; arguments unchanged."),
      construction_min_core_kme_size = 30/3, power = 6, omitted_arguments = "Preserved; see recorded formals and script.")
    stage("Manu_cell_1", "finished")

    stage("Manu_cell_3")
# BEGIN MANU CELL 3 (installation statements excluded)
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
# END MANU CELL 3
    stage("Manu_cell_3", "finished")

    stage("Manu_cell_5")
# BEGIN MANU CELL 5 (installation statements excluded)
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
# END MANU CELL 5
    provenance$network <- list(block_sizes = lengths(net$blockGenes), goodSamples = net$goodSamples,
      goodGenes = net$goodGenes, module_sizes = table(net$colors), MEsOK = net$MEsOK)
    stage("Manu_cell_5", "finished")

    stage("Manu_cell_6")
# BEGIN MANU CELL 6 (installation statements excluded)
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
# END MANU CELL 6
    stage("Manu_cell_6", "finished")

    stage("Manu_cell_9")
# BEGIN MANU CELL 9 (installation statements excluded)
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
# END MANU CELL 9
    stage("Manu_cell_9", "finished")

    stage("Manu_cell_10")
# BEGIN MANU CELL 10 (installation statements excluded)
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
# END MANU CELL 10
    stage("Manu_cell_10", "finished")

    stage("Manu_cell_13")
# BEGIN MANU CELL 13 (installation statements excluded)
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
# END MANU CELL 13
    # Resource adaptation: all degree diagnostics have consumed adjMat. IMC survives cell 16.
    rm(adjMat)
    gc()
    stage("Manu_cell_13", "finished")

    stage("Manu_cell_15")
# BEGIN MANU CELL 15 (installation statements excluded)
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
# END MANU CELL 15
    stage("Manu_cell_15", "finished")

    stage("Manu_cell_16")
# BEGIN MANU CELL 16 (installation statements excluded)
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
# END MANU CELL 16
    stage("Manu_cell_16", "finished")

    stage("Manu_cell_47")
# BEGIN MANU CELL 47 (installation statements excluded)
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
# END MANU CELL 47
    stage("Manu_cell_47", "finished")

    stage("validate_outputs")
    if (!identical(rownames(MEs), rownames(expr)) || !identical(names(net$colors), colnames(expr)) ||
        !identical(rownames(kMEtab), colnames(expr)) || !identical(masterNodes$Gene, colnames(expr)) ||
        nrow(IMC) != ncol(expr)) fail("Output identifier/order validation failed.")
    if (length(final_hub_genes) != 350L || nrow(final_hub_info) != 350L ||
        anyNA(final_hub_info) || anyDuplicated(final_hub_info$Gene) ||
        !all(final_hub_genes %in% colnames(expr))) fail("Final panel is incomplete; no analytical repair attempted.")
    required <- c("soft_thresholding_results.csv", "scale_free_topology.png", net$TOMFiles,
      "WGCNA_results_power6.RData", "module_summary.csv", "module_trait_correlations.csv",
      "module_trait_pvalues.csv", "module_trait_FDR.csv", "module_trait_summary.csv", "module_trait_heatmap.png",
      paste0(names(cols_FDR), "_FDR_genes.csv"), "adjacency_degree_dist.png", "degree_stats.RData",
      "kME_table.RData", "kME_vs_kWithin.png", "masterNodes.csv", "final_hub_genes_info.csv", "final_hub_genes.csv")
    if (!length(net$TOMFiles) || anyNA(required) || any(!file.exists(required)) ||
        any(file.info(required)$size <= 0)) fail("Required artifacts missing or empty.")
    # Read back RData in isolation, one at a time; do not retain another TOM.
    for (path in required[grepl("\\.RData$", required)]) {
      e <- new.env(parent = emptyenv())
      objects <- load(path, envir = e)
      if (path %in% net$TOMFiles) {
        block <- match(path, net$TOMFiles)
        if (!identical(objects, "TOM") || !inherits(e$TOM, "dist") ||
            attr(e$TOM, "Size") != length(net$blockGenes[[block]]) ||
            length(e$TOM) != choose(length(net$blockGenes[[block]]), 2)) fail("Invalid saved TOM.")
      } else if (path == "WGCNA_results_power6.RData") {
        if (!identical(e$net, net) || !identical(e$MEs, MEs) || !identical(e$module_summary, module_summary))
          fail("Network checkpoint readback differs.")
      } else if (path == "kME_table.RData") {
        if (!identical(e$kMEtab, kMEtab) || !identical(e$kME_summ, kME_summ)) fail("kME readback differs.")
      } else if (!identical(e$deg_stats, deg_stats)) fail("Degree statistics readback differs.")
      rm(e)
      gc()
    }
    for (path in required[grepl("\\.csv$", required)]) {
      tab <- read.csv(path, check.names = FALSE)
      expected_rows <- if (path == "soft_thresholding_results.csv") 40L else if (path == "masterNodes.csv") ncol(expr) else
        if (path == "final_hub_genes_info.csv") 350L else if (path == "final_hub_genes.csv") 350L else
        if (grepl("_FDR_genes.csv$", path)) sum(geneMod$Module %in% cols_FDR[[sub("_FDR_genes.csv$", "", path)]]) else ncol(MEs)
      if (nrow(tab) != expected_rows) fail(paste("CSV row count differs:", path))
      if (path == "masterNodes.csv" && !identical(tab$Gene, colnames(expr))) fail("Saved node IDs differ.")
      if (path == "final_hub_genes.csv" && !identical(tab$Gene, final_hub_genes)) fail("Saved panel IDs differ.")
    }
    for (path in required[grepl("\\.png$", required)]) {
      signature <- readBin(path, "raw", n = 8L)
      if (!identical(signature, as.raw(c(137, 80, 78, 71, 13, 10, 26, 10)))) fail(paste("Invalid PNG:", path))
    }
    provenance$required_outputs <- required
    provenance$observed <- list(ME_dimensions = dim(MEs), kME_dimensions = dim(kMEtab),
      final_hub_count = length(final_hub_genes), panel_identity = "Manual historical assignment; kME identity provisional.")
    stage("validate_outputs", "finished")
    provenance$analysis_status <- "completed"
  }, warning = function(w) {
    record <- list(utc = utc(), stage = provenance$current_stage, message = conditionMessage(w),
                   call = deparse(conditionCall(w)))
    provenance$warnings[[length(provenance$warnings) + 1L]] <<- record
    cat("WARNING", record$utc, record$stage, record$message, "\n")
    flush(log_connection)
    persist() # Preserve immediately, without muffling or changing warning options.
  }, message = function(m) {
    # The default message handler writes after this calling handler returns.
    # Write/flush a labelled copy now; leave the original message unsuppressed.
    cat("MESSAGE", utc(), provenance$current_stage, conditionMessage(m), "\n")
    flush(log_connection)
  }, error = function(e) {
    # Calling handler preserves the originating stack before tryCatch unwinds it.
    provenance$failure_calls <<- lapply(sys.calls(), deparse)
    tryCatch(persist(), error = function(persistence_error) {
      try(writeLines(c(paste("Original error:", conditionMessage(e)),
        paste("Provenance persistence error:", conditionMessage(persistence_error)),
        unlist(provenance$failure_calls)), "persistence_failure.txt"), silent = TRUE)
    })
  }), error = function(e) {
    provenance$analysis_status <<- "failed"
    provenance$errors[[length(provenance$errors) + 1L]] <<- list(utc = utc(), stage = provenance$current_stage,
      message = conditionMessage(e), call = deparse(conditionCall(e)), calls = lapply(sys.calls(), deparse))
    cat("ERROR", conditionMessage(e), "\n")
    flush(log_connection)
  })
  # Finalize devices on success AND caught failure before any artifact hashing.
  finalization_error <- NULL
  tryCatch({
    graphics.off()
    if (length(dev.list())) fail("Graphics devices remain open after graphics.off().")
  }, error = function(e) {
    finalization_error <<- conditionMessage(e)
    provenance$analysis_status <<- "failed"
    provenance$errors[[length(provenance$errors) + 1L]] <<- list(utc = utc(),
      stage = "graphics_finalization", message = conditionMessage(e))
    cat("GRAPHICS FINALIZATION ERROR", conditionMessage(e), "\n")
    flush(log_connection)
  })
  # SIGKILL/OOM cannot reach this finalizer; external records remain essential.
  # Any finalization failure prohibits a completion marker, including persistence/hash failures.
  marker_temporary <- NULL
  tryCatch({
    provenance$finished_utc <- utc()
    writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
    persist()
    flush(log_connection)
    if (!is.null(finalization_error)) fail(paste("Graphics closure failed:", finalization_error))
    # Close logging before checksumming it, so no later writes invalidate its digest.
    sink(type = "message")
    sink()
    close(log_connection)
    on.exit(setwd(root), add = FALSE)
    manifest_hash <- manifest()
    if (identical(provenance$analysis_status, "completed")) {
      marker_temporary <- tempfile(pattern = ".COMPLETED-", tmpdir = ".")
      writeLines(c(paste("completed_utc", utc()), paste("artifact_manifest_sha256", manifest_hash),
        "Manifest covers finalized artifacts except itself and this marker."), marker_temporary)
      if (!file.rename(marker_temporary, "COMPLETED")) fail("Completion marker rename failed.")
    }
  }, error = function(e) {
    # Separate best-effort fallback even if atomic provenance persistence is unavailable.
    diagnostic <- paste(utc(), "FINALIZATION FAILED:", conditionMessage(e))
    try(writeLines(diagnostic, "finalization_failure.txt"), silent = TRUE)
    if (!is.null(marker_temporary) && file.exists(marker_temporary)) {
      if (unlink(marker_temporary) != 0L)
        try(write("Could not remove temporary completion marker.", stderr()), silent = TRUE)
    }
    if (file.exists("COMPLETED")) unlink("COMPLETED")
    fail(paste(diagnostic, "Run directory:", output_dir))
  })
  # Ordinary analysis failure is propagated after successful partial-run finalization.
  # Do not create another file after its manifest or label it a finalization failure.
  if (!identical(provenance$analysis_status, "completed")) fail(paste("WGCNA failed; inspect", output_dir))
  invisible(output_dir)
}
main()
