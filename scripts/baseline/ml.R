#!/usr/bin/env Rscript
# Faithful selected Manu branch. Parse/static review does not execute this script.
main <- function() {
  stop_ml <- function(x) stop(x, call. = FALSE)
  root <- normalizePath(getwd(), mustWork = TRUE)
  if (interactive() || !any(grepl("^--file=", commandArgs())) ||
      !file.exists("AGENTS.md")) stop_ml("Use fresh Rscript from repository root.")
  if (!requireNamespace("renv", quietly = TRUE) ||
      normalizePath(renv::project()) != root) stop_ml("Project renv activation required.")
  source(file.path(root, "scripts/baseline/ml-support.R"), local = TRUE)
  sha <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
  git <- function(args) {
    x <- system2("git", args, stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(x, "status"))) stop_ml("Git inspection failed.")
    x
  }
  repository <- list(head = git(c("rev-parse", "HEAD")),
    branch = git(c("branch", "--show-current")), status = git(c("status", "--porcelain=v1")))
  if (repository$branch != "analysis/initial-review" || length(repository$status))
    stop_ml("Review implementation and require clean analysis/initial-review before execution.")
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop_ml("Arguments: VERIFIED_PANEL_DIRECTORY REVIEWED_ML_LOCKFILE")
  panel_dir <- normalizePath(args[1], mustWork = TRUE)
  ml_lock_path <- normalizePath(args[2], mustWork = TRUE)
  base <- file.path(root, "Results/baseline_ml")
  dir.create(base, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(base, paste0("run-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", Sys.getpid()))
  if (file.exists(out) || !dir.create(out)) stop_ml("Cannot create exclusive run directory.")
  setwd(out)
  on.exit(setwd(root), add = TRUE)
  atomic <- function(path, writer) {
    temp <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
    writer(temp)
    if (!file.rename(temp, path)) stop_ml(paste("Atomic publication failed:", path))
  }
  utc <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
  state <- list(workflow_status = "preflight_blocked", repository = repository,
    started_utc = utc(), stages = setNames(rep(list(list(status = "not_reached")), 5L),
      paste0("cell_", c(55L,57L,58L,59L,60L))), warnings = list(), messages = list(),
    models = list(RF = "not_reached", SVM = "not_reached", logistic = "not_reached"),
    comparisons = list(), historical_failure_cause = "not_verifiable",
    failure_comparison = "not_verifiable", failure_comparison_policy = "Manual assessment of captured diagnostics required",
    leakage = c("Full-cohort supervised panel selection precedes split",
      "Full-cohort preprocessing", "Split is not patient/study grouped",
      "Test-outcome-selected ROC direction", "Confounded study/category; no independent validation"))
  persist <- function() atomic("execution_provenance.rds", function(p) saveRDS(state, p))
  log <- file("execution.log", "wt")
  sink(log, split = TRUE)
  sink(log, type = "message")
  logging <- TRUE
  close_log <- function() {
    if (logging) { sink(type = "message"); sink(); flush(log); close(log); logging <<- FALSE }
  }
  on.exit(close_log(), add = TRUE)
  # Notebook formula/terms environments must be .GlobalEnv, never main() or a child.
  env <- .GlobalEnv
  stage <- "preflight"
  model_for_cell <- c(`58` = "RF", `59` = "SVM", `60` = "logistic")
  ids <- function(x) is.character(x) && length(x) > 0L && !anyNA(x) &&
    all(nzchar(x)) && all(trimws(x) == x) && !anyDuplicated(x)
  assert <- function(ok, message) if (!isTRUE(ok)) stop_ml(message)
  seed <- function() if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
    get(".Random.seed", .GlobalEnv) else NULL
  roundtrip <- function(x, path) {
    saveRDS(x, path)
    assert(identical(x, readRDS(path)), paste("Read-back failed:", path))
  }
  completed_model <- function(label, object, prediction, probability, confmat, aucs) {
    truth <- env$test$Subtype
    samples <- rownames(env$test)
    assert(length(prediction) == length(truth) && !anyNA(prediction), "Invalid predictions")
    probability_matrix <- ml_probability_matrix(probability, samples, levels(truth))
    assert(is.null(names(prediction)) || identical(names(prediction), samples), "Prediction row alignment")
    names(prediction) <- samples
    names(truth) <- samples
    # Additional evaluation only; does not change source prediction or ROC direction.
    rocs <- lapply(levels(truth), function(lbl)
      pROC::roc(as.numeric(truth == lbl), probability_matrix[, lbl], quiet = TRUE))
    names(rocs) <- levels(truth)
    recomputed <- vapply(rocs, function(x) as.numeric(x$auc), numeric(1))
    assert(isTRUE(all.equal(unname(recomputed), unname(as.numeric(aucs)))), "AUC inconsistency")
    accuracy <- mean(prediction == truth)
    assert(isTRUE(all.equal(accuracy, unname(confmat$overall["Accuracy"]))), "Accuracy inconsistency")
    assert(identical(unname(table(prediction, truth)), unname(confmat$table)), "Confusion matrix inconsistency")
    evidence <- list(model = object, prediction = prediction, probability = probability,
      truth = truth, confusion = confmat, auc = recomputed,
      roc_settings = lapply(rocs, function(x) list(levels = x$levels, direction = x$direction)),
      accuracy = accuracy, rng_after = seed(),
      effective_model = if (label == "logistic") object[c("method", "control", "tuneGrid", "bestTune", "results", "resample", "trainingData")] else NULL)
    state$model_files[[label]] <<- list(evidence_sha256 =
      ml_check_evidence_readback(evidence, paste0(label, "_evidence.rds"), sha))
    expected <- if (label == "RF") matrix(c(7,0,0,0, 0,12,0,0, 1,1,12,0, 0,0,0,48), 4) else
      if (label == "SVM") matrix(c(7,0,0,0, 0,12,0,0, 0,1,13,0, 0,0,0,48), 4) else NULL
    state$comparisons[[label]] <<- if (is.null(expected)) "differs_from_checkpoint" else
      if (identical(as.numeric(confmat$table), as.numeric(expected)) && ml_auc_matches(recomputed))
        "matches_available_checkpoint" else "differs_from_checkpoint"
    # Validate source-requested model checkpoint in an isolated environment.
    source_file <- switch(label, RF = "rf_hub_panel_validation.RData",
      SVM = "svm_hub_panel_validation.RData", logistic = "logreg_hub_panel_validation.RData")
    source_names <- switch(label, RF = c("rf_mod", "confmat", "auc_list"),
      SVM = c("svm_mod", "svm_confmat", "auc_list_svm"),
      logistic = c("logreg_mod", "logreg_confmat", "auc_list_logreg"))
    state$model_files[[label]]$checkpoint_sha256 <<- ml_check_checkpoint(source_file,
      mget(source_names, envir = env), source_names[1], sha)
    if (label == "RF") for (path in c("rf_multiclass_roc.png", "rf_varimp.png")) {
      con <- file(path, "rb")
      signature <- readBin(con, "raw", 8L); close(con)
      assert(identical(signature, as.raw(c(137,80,78,71,13,10,26,10))), "Invalid RF PNG")
    }
    # This compares available printed precision, not historical probability bytes.
    persist()
  }
  caught <- tryCatch(withCallingHandlers({
    lock <- renv::lockfile_read(file.path(root, "renv.lock"))
    extension <- renv::lockfile_read(ml_lock_path)
    assert(length(lock$Packages) == 113L, "Unexpected baseline lock")
    for (p in names(lock$Packages)) assert(identical(lock$Packages[[p]], extension$Packages[[p]]),
      paste("ML lock changed baseline record:", p))
    assert(identical(lock$R, extension$R) && identical(lock$Bioconductor, extension$Bioconductor),
      "ML lock changed baseline R/repositories/Bioconductor")
    direct <- c("randomForest", "caret", "pROC", "e1071", "nnet")
    assert(all(direct %in% names(extension$Packages)), "Reviewed ML lock lacks dependencies")
    lib <- renv::paths$library(project = root)
    expected <- vapply(extension$Packages, function(x) x$Version, "")
    ip <- installed.packages(lib.loc = lib)
    assert(as.character(getRversion()) == lock$R$Version &&
      as.character(packageVersion("renv")) == lock$Packages$renv$Version &&
      identical(renv::settings$bioconductor.version(), lock$Bioconductor$Version) &&
      all(names(expected) %in% rownames(ip)) &&
      identical(unname(ip[names(expected), "Version"]), unname(expected)), "Restore reviewed ML project library")
    for (p in names(expected)) assert(identical(normalizePath(find.package(p)),
      normalizePath(file.path(lib, p))), paste("Package outside project library:", p))
    write.csv(ip[, c("Package", "Version", "LibPath")], "package_versions.csv", row.names = FALSE)
    pinned <- c("renv.lock", "renv/settings.json", "renv/activate.R", ".Rprofile",
      "scripts/baseline/ml.R", "scripts/baseline/ml-support.R", "notebooks/original/Original_Manu_Pipe.ipynb")
    state$source_hashes <- setNames(vapply(file.path(root, pinned), sha, ""), pinned)
    assert(state$source_hashes[["notebooks/original/Original_Manu_Pipe.ipynb"]] ==
      "ca9671af2eb21bf551641d1e01bfebef5926c1547fee60c86e6bc06caff2f45c", "Notebook hash mismatch")
    state$ml_lock <- list(path = ml_lock_path, sha256 = sha(ml_lock_path), records = extension$Packages)
    assert(identical(RNGkind(), c("Mersenne-Twister", "Inversion", "Rejection")), "Unexpected RNG kind")
    state$environment <- list(R = R.version, RNGkind = RNGkind(), BLAS = extSoftVersion(),
      threads = Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")),
      parallel_backend = "No backend registered by wrapper", cpu = parallel::detectCores())
    input_base <- file.path(root, "Results/baseline_preprocessing/run-20261013T053229Z-205981")
    paths <- c(file.path(input_base, c("expression_samples_by_genes.rds", "aligned_metadata.rds", "execution_provenance.rds")),
      file.path(panel_dir, c("final_hub_genes.csv", "final_hub_genes_info.csv")))
    hashes <- c("c5d30758d2fdad1bbb980845958e61370c7a67592130f6e41b4ec0837449b3b4",
      "c6b766098f7d4dea34e60fa7b7167994f4845d983f5a57366547713a77a04644",
      "10bae632b4abd190267bd960640d265ece960b5616841aca65de213ced20f9c7",
      "68ab1b6052ecbf3b9882eb66d7046aea3bab0ae3501fdae32bb647c4738b2335",
      "4255abb160a36176b128dc9d46f5679e98e83c86300441365e739ab3711911be")
    assert(all(file.exists(paths)) && identical(unname(vapply(paths, sha, "")), hashes), "Input checksum mismatch")
    state$inputs <- data.frame(path = paths, sha256 = hashes)
    expr <- readRDS(paths[1]); metadata <- readRDS(paths[2])
    state$preprocessing <- readRDS(paths[3])
    panel <- read.csv(paths[4], colClasses = "character", check.names = FALSE)
    info <- read.csv(paths[5], colClasses = "character", check.names = FALSE)
    assert(identical(names(panel), "Gene") && "Gene" %in% names(info), "Panel schema mismatch")
    genes <- panel$Gene
    assert(identical(dim(expr), c(279L, 25750L)) && is.numeric(expr) && all(is.finite(expr)) &&
      ids(rownames(expr)) && ids(colnames(expr)), "Expression schema mismatch")
    assert(identical(rownames(metadata), rownames(expr)) && nrow(metadata) == 279L &&
      identical(names(metadata), c("batch", "Subtype")) && is.factor(metadata$batch) &&
      !is.ordered(metadata$batch) && !anyNA(metadata$batch) &&
      identical(levels(metadata$batch), c("GSE243375", "GSE52194", "GSE58135")) &&
      is.factor(metadata$Subtype) && !is.ordered(metadata$Subtype) &&
      identical(levels(metadata$Subtype), c("Normal", "ERpos", "TNBC", "HER2pos")) &&
      identical(as.integer(table(metadata$Subtype)), c(26L,42L,48L,163L)), "Metadata schema/order mismatch")
    assert(ids(genes) && length(genes) == 350L && identical(genes, info$Gene) &&
      all(genes %in% colnames(expr)), "Panel identity/order mismatch")
    mapped <- make.names(genes)
    assert(!anyDuplicated(mapped) && !"Subtype" %in% mapped, "Ambiguous transformed feature names")
    write.csv(data.frame(original = genes, transformed = mapped), "feature_name_mapping.csv", row.names = FALSE)
    env$expr <- expr; env$metadata <- metadata; env$final_hub_genes <- genes
    rm(expr, metadata)
    notebook <- jsonlite::fromJSON(file.path(root, "notebooks/original/Original_Manu_Pipe.ipynb"), simplifyVector = FALSE)
    source_cells <- c(48L,52L,55L,56L,57L,58L,59L,60L,133L:139L)
    dir.create("source_cells")
    cell_records <- lapply(source_cells, function(i) {
      text <- paste0(unlist(notebook$cells[[i]]$source), collapse = "")
      path <- file.path("source_cells", paste0(i, ".R"))
      cat(text, file = path)
      list(cell = i, sha256 = sha(path), selected = i %in% c(55L,57L,58L,59L,60L))
    })
    state$cells <- cell_records
    persist()
    # Resolve namespaces/defaults BEFORE cell 57 resets RNG. Never load a new
    # namespace or model definition between the split and RF fitting.
    for (p in direct) assert(requireNamespace(p, quietly = TRUE), paste("Cannot load", p))
    defaults <- list(randomForest_default = formals(randomForest:::randomForest.default),
      svm_default = formals(e1071:::svm.default), train_default = formals(caret:::train.default),
      trainControl = formals(caret::trainControl), multinom = formals(nnet::multinom),
      roc_default = formals(pROC:::roc.default), caret_multinom = caret::getModelInfo("multinom", regex = FALSE))
    saveRDS(defaults, "effective_defaults.rds")
    for (cell in names(cells)) {
      stage <- paste0("cell_", cell)
      state$stages[[stage]] <- list(status = "started", utc = utc(), rng_before = seed())
      original <- paste0(unlist(notebook$cells[[as.integer(cell)]]$source), collapse = "")
      analytical <- paste0(strsplit(original, "\n", fixed = TRUE)[[1]][
        !grepl("^install[.]packages\\(", strsplit(original, "\n", fixed = TRUE)[[1]])], collapse = "\n")
      assert(identical(sub("\n$", "", cells[[cell]]), analytical), paste("Source fidelity failed:", cell))
      cat("STAGE", stage, "started", utc(), "\n"); flush(log); persist()
      evaluate <- function() {
        value <- eval(parse(text = cells[[cell]], keep.source = TRUE), envir = env)
        state$stages[[stage]]$rng_after_source <<- seed()
        value
      }
      validate <- function() {

        if (cell == "55") {
          assert(identical(dim(env$ml_matrix), c(279L,350L)), "ML dimensions changed")
          roundtrip(list(matrix = env$ml_matrix, data = env$ml_df, metadata = env$metadata), "ml_bridge.rds")
          exported <- read.csv("ml_input_hub_panel.csv", row.names = 1, check.names = FALSE)
          assert(identical(rownames(exported), rownames(env$ml_df)) &&
            identical(names(exported), names(env$ml_df)) &&
            isTRUE(all.equal(as.matrix(exported[, -351L]), env$ml_matrix, tolerance = 1e-12)) &&
            identical(exported$Subtype, as.character(env$ml_df$Subtype)), "Bridge CSV read-back mismatch")
        }
        if (cell == "57") {
          roundtrip(list(indices = env$train_idx, train_samples = rownames(env$train),
            test_samples = rownames(env$test), train_counts = table(env$train$Subtype),
            test_counts = table(env$test$Subtype), levels = levels(env$ml_df$Subtype),
            rng_after_split = state$stages$cell_57$rng_after_source), "split.rds")
          state$comparisons$split <<- if (nrow(env$train) == 198L && nrow(env$test) == 81L &&
            identical(as.integer(table(env$train$Subtype)), c(19L,30L,34L,115L)) &&
            identical(as.integer(table(env$test$Subtype)), c(7L,12L,14L,48L)))
            "matches_available_checkpoint" else "differs_from_checkpoint"
          # Binding inspection consumes no random numbers before RF.
          bindings <- lapply(c("randomForest", "createDataPartition", "roc", "train"), function(n) {
            f <- get(n, envir = env, mode = "function")
            list(name = n, environment = environmentName(environment(f)), formals = formals(f))
          })
          saveRDS(bindings, "function_bindings.rds")

        }
        if (cell == "58") completed_model("RF", env$rf_mod, env$rf_pred, env$test_probs, env$confmat, env$auc_list)
        if (cell == "59") completed_model("SVM", env$svm_mod, env$svm_pred, env$svm_probs, env$svm_confmat, env$auc_list_svm)
        if (cell == "60") completed_model("logistic", env$logreg_mod, env$logreg_pred, env$logreg_probs, env$logreg_confmat, env$auc_list_logreg)
      }
      if (cell %in% names(model_for_cell)) {
        result <- ml_run_branch(evaluate, validate, precheck = function() {
          if (cell == "58") ml_assert_rng(state$stages$cell_57$rng_after_source, seed())
        })
        label <- unname(model_for_cell[[cell]])
        state$models[[label]] <- result$status
        state$stages[[stage]]$branch_result <- result
        state$stages[[stage]]$status <- result$status
        if (result$status != "succeeded") state$comparisons[[label]] <- "not_verifiable"
      } else {
        # Preparation/split are prerequisites for every model: failure aborts.
        ml_run_preparation(evaluate, validate)
        state$stages[[stage]]$status <- "succeeded"
      }
      state$stages[[stage]]$rng_after <- seed()
      cat("STAGE", stage, state$stages[[stage]]$status, utc(), "\n"); flush(log); persist()
    }
    state$workflow_status <- ml_workflow_status(state$models)
    state$failure_comparison <- "not_verifiable"
    NULL
  }, warning = function(w) {
    state$warnings[[length(state$warnings) + 1L]] <<- list(stage = stage, text = conditionMessage(w), call = deparse(conditionCall(w)))
    cat("WARNING", conditionMessage(w), "\n"); flush(log)
  }, message = function(m) {
    state$messages[[length(state$messages) + 1L]] <<- list(stage = stage, text = conditionMessage(m))
    cat("MESSAGE", conditionMessage(m), "\n"); flush(log)
  }), error = function(e) {
    state$error <<- list(stage = stage, text = conditionMessage(e), call = deparse(conditionCall(e)))
    state$workflow_status <<- ml_outer_failure_status(stage)
    state$stages[[stage]] <<- list(status = "failed", error = state$error, rng_at_failure = seed())
    e
  })
  # Wrapper finalisation failure never publishes a review-finalization record.
  exit <- tryCatch({
    graphics.off()
    assert(is.null(dev.list()), "Graphics finalisation failed")
    state$finished_utc <- utc()
    state$resources <- list(process_time = proc.time(), proc_status =
      if (file.exists("/proc/self/status")) readLines("/proc/self/status") else "unavailable")
    persist()
    writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
    cat("WORKFLOW", state$workflow_status, "\n"); flush(log)
    close_log()
    paths <- sort(list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE))
    paths <- paths[!file.info(paths)$isdir]
    manifest <- data.frame(path = paths, bytes = file.info(paths)$size,
      sha256 = vapply(paths, sha, ""))
    write.csv(manifest, "artifact_checksums.csv", row.names = FALSE)
    check <- read.csv("artifact_checksums.csv", colClasses = c("character", "numeric", "character"))
    assert(identical(check$path, paths) && identical(check$bytes, unname(file.info(paths)$size)) &&
      identical(check$sha256, unname(vapply(check$path, sha, ""))), "Manifest read-back failed")
    if (state$workflow_status == "wrapper_failed") return(1L)
    report <- list(workflow_status = state$workflow_status, models = state$models,
      historical_comparisons = state$comparisons, failure_comparison = state$failure_comparison,
      failed_stages = names(Filter(function(x) !x$status %in% c("succeeded", "not_reached"), state$stages)),
      artifact_manifest_sha256 = sha("artifact_checksums.csv"),
      meaning = "Audit finalisation only; not analysis success or independent validation.")
    atomic("review-finalization.json", function(p) jsonlite::write_json(report, p, auto_unbox = TRUE, pretty = TRUE, null = "null"))
    switch(state$workflow_status, finished_all_models_succeeded = 0L,
      finished_with_model_failure = 3L, finished_with_preparation_failure = 3L, preflight_blocked = 2L, 1L)
  }, error = function(e) {
    close_log()
    writeLines(c("WRAPPER FINALISATION FAILED", conditionMessage(e)), "finalization_failure.txt")
    1L
  })
  exit
}

cells <- list(
  `55` = r"---(###############################################################################
## 17-A: Build ML Feature Matrix for Final Hub Gene Panel
###############################################################################
# Features: final_hub_genes (vector of 350 gene symbols)
# Expression matrix: expr (samples × all genes)
# Labels: metadata$Subtype

# Filter expr to only final hub genes (ensure order matches!)
ml_features <- intersect(final_hub_genes, colnames(expr))  # should be all 350
ml_matrix   <- expr[, ml_features, drop = FALSE]

cat("ML input matrix dim:", dim(ml_matrix), "\n")    # Expect (samples × 350)
cat("First 5 genes:", paste(colnames(ml_matrix)[1:5], collapse = ", "), "\n")

# Confirm all hub genes present
if (length(ml_features) < 350) {
  warning(sprintf("Some hub genes missing from expr! Found %d / 350", length(ml_features)))
}

# Make column names syntactically valid in R
colnames(ml_matrix) <- make.names(colnames(ml_matrix))


# Attach labels
ml_df <- as.data.frame(ml_matrix)
ml_df$Subtype <- metadata$Subtype

# Output check: label distribution
cat("Label distribution in ML input:\n")
print(table(ml_df$Subtype))

# Optional: Save for reference
write.csv(ml_df, "ml_input_hub_panel.csv", row.names = TRUE))---",
  `57` = r"---(###############################################################################
## 17-B: Train/Test Split and Random Forest Model
###############################################################################
library(randomForest)
library(caret)
library(pROC)

set.seed(2024)
train_idx <- createDataPartition(ml_df$Subtype, p = 0.7, list = FALSE)
train <- ml_df[train_idx, ]
test  <- ml_df[-train_idx, ]

cat("Training set:", nrow(train), "samples\n")
cat("Test set:", nrow(test), "samples\n")
cat("Training subtype distribution:\n")
print(table(train$Subtype))
cat("Test subtype distribution:\n")
print(table(test$Subtype)))---",
  `58` = r"---(###############################################################################
## Train Random Forest (using 350 hub genes) and Output Checks
###############################################################################
rf_mod <- randomForest(
  Subtype ~ .,
  data = train,
  importance = TRUE,
  ntree = 1000
)

rf_pred <- predict(rf_mod, test, type = "class")

# Evaluation
confmat <- confusionMatrix(rf_pred, test$Subtype)
cat("\nRandom Forest: Accuracy =", round(confmat$overall["Accuracy"], 3), "\n")
print(confmat$table)

# Per-class ROC curves (one-vs-rest)
test_probs <- predict(rf_mod, test, type = "prob")
auc_list <- sapply(levels(test$Subtype), function(lbl) {
  roc(as.numeric(test$Subtype == lbl), test_probs[, lbl])$auc
})
cat("\nPer-class ROC-AUC:\n")
print(auc_list)

# Plot ROC curves (optional, saves PNG)
png("rf_multiclass_roc.png", 2000, 1600, res = 200)
plot(roc(as.numeric(test$Subtype == levels(test$Subtype)[1]), test_probs[, 1]),
     col = "red", main = "Random Forest – Multi-class ROC")
for(i in 2:length(levels(test$Subtype))) {
  plot(roc(as.numeric(test$Subtype == levels(test$Subtype)[i]), test_probs[, i]),
       col = i, add = TRUE)
}
legend("bottomright", legend = levels(test$Subtype), col = 1:4, lty = 1)
dev.off()

# Variable importance
png("rf_varimp.png", 1600, 1200, res = 200)
varImpPlot(rf_mod, main = "Random Forest – Top Features")
dev.off()

# Save all for reproducibility
save(rf_mod, confmat, auc_list, file = "rf_hub_panel_validation.RData")

# Summarize
cat("\nRF Accuracy:", round(confmat$overall["Accuracy"], 3), "\n")
cat("Per-class AUCs:\n")
print(auc_list)
cat("Confusion matrix:\n")
print(confmat$table)
)---",
  `59` = r"---(###############################################################################
## 17-D: Train and Evaluate Support Vector Machine (SVM)
###############################################################################
library(e1071)
library(caret)
library(pROC)

# Prepare input (reuse previous train/test split)
x_train <- train[, !(names(train) %in% "Subtype")]
y_train <- train$Subtype
x_test  <- test[, !(names(test) %in% "Subtype")]
y_test  <- test$Subtype

# Train SVM (radial basis kernel, multi-class)
set.seed(2024)
svm_mod <- svm(x = x_train, y = y_train,
               kernel = "radial",
               probability = TRUE)

# Predict
svm_pred <- predict(svm_mod, x_test)
svm_probs <- attr(predict(svm_mod, x_test, probability=TRUE), "probabilities")

# Evaluation
svm_confmat <- confusionMatrix(svm_pred, y_test)
cat("\nSVM: Accuracy =", round(svm_confmat$overall["Accuracy"], 3), "\n")
print(svm_confmat$table)

# Per-class ROC-AUC
auc_list_svm <- sapply(levels(y_test), function(lbl) {
  # "probabilities" has columns in same order as levels(y_test)
  roc(as.numeric(y_test == lbl), svm_probs[, lbl])$auc
})
cat("\nSVM Per-class ROC-AUC:\n")
print(auc_list_svm)

# Save
save(svm_mod, svm_confmat, auc_list_svm, file = "svm_hub_panel_validation.RData")
)---",
  `60` = r"---(###############################################################################
## 17-E: Multinomial Logistic Regression
###############################################################################
library(nnet)
library(caret)
library(pROC)

# caret::train makes this simple
set.seed(2024)
logreg_mod <- train(
  Subtype ~ .,
  data = train,
  method = "multinom",
  trace = FALSE
)

# Predict
logreg_pred <- predict(logreg_mod, test)
logreg_probs <- predict(logreg_mod, test, type = "prob")

# Evaluation
logreg_confmat <- confusionMatrix(logreg_pred, test$Subtype)
cat("\nLogistic Regression: Accuracy =", round(logreg_confmat$overall["Accuracy"], 3), "\n")
print(logreg_confmat$table)

# Per-class ROC-AUC
auc_list_logreg <- sapply(levels(test$Subtype), function(lbl) {
  roc(as.numeric(test$Subtype == lbl), logreg_probs[, lbl])$auc
})
cat("\nLogistic Regression Per-class ROC-AUC:\n")
print(auc_list_logreg)

# Save
save(logreg_mod, logreg_confmat, auc_list_logreg, file = "logreg_hub_panel_validation.RData")
)---"
)
quit(status = main(), save = "no")
