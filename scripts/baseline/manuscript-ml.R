#!/usr/bin/env Rscript
# Separate manuscript branch. Never source this runner for syntax checks.
main <- function() {
  stop_ml <- function(x) stop(x, call. = FALSE)
  root <- normalizePath(getwd(), mustWork = TRUE)
  if (interactive() || !any(grepl("^--file=", commandArgs())) ||
      !file.exists("AGENTS.md")) stop_ml("Use fresh Rscript from repository root.")
  if (!requireNamespace("renv", quietly = TRUE) ||
      normalizePath(renv::project()) != root) stop_ml("Project renv activation required.")
  source(file.path(root, "scripts/baseline/ml-support.R"), local = TRUE)
  source(file.path(root, "scripts/baseline/manuscript-ml-support.R"), local = TRUE)
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
  if (length(args) != 5L) stop_ml("Arguments: RECOVERED_NOTEBOOK VERIFIED_PANEL_DIRECTORY REVIEWED_MANUSCRIPT_LOCKFILE XGBOOST_API_REVIEW_JSON RETAINED_MANU_ML_LOCKFILE")
  notebook_path <- normalizePath(args[1], mustWork = TRUE)
  panel_dir <- normalizePath(args[2], mustWork = TRUE)
  ml_lock_path <- normalizePath(args[3], mustWork = TRUE)
  api_review_path <- normalizePath(args[4], mustWork = TRUE)
  retained_lock_path <- normalizePath(args[5], mustWork = TRUE)
  base <- file.path(root, "Results/baseline_manuscript_ml")
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
    started_utc = utc(), stages = setNames(rep(list(list(status = "not_reached")), 6L),
      paste0("cell_", 69L:74L)), warnings = list(), messages = list(),
    models = list(RF = "not_reached", SVM = "not_reached", LR = "not_reached", XGB = "not_reached"),
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
  model_for_cell <- c(`71` = "RF", `72` = "SVM", `73` = "LR", `74` = "XGB")
  last_source_seed <- NULL
  ids <- function(x) is.character(x) && length(x) > 0L && !anyNA(x) &&
    all(nzchar(x)) && all(trimws(x) == x) && !anyDuplicated(x)
  assert <- function(ok, message) if (!isTRUE(ok)) stop_ml(message)
  seed <- function() if (exists(".Random.seed", .GlobalEnv, inherits = FALSE))
    get(".Random.seed", .GlobalEnv) else NULL
  roundtrip <- function(x, path) {
    saveRDS(x, path)
    assert(identical(x, readRDS(path)), paste("Read-back failed:", path))
  }
  summary_rows <- list()
  capture_model <- function(label) {
    spec <- switch(label, RF = c("rf", "rf_pred", "rf_prob", "auc_rf", "cm_rf", "8"),
      SVM = c("svm_mod", "svm_pred", "svm_prob", "auc_svm", "cm_svm", "13"),
      LR = c("logreg", "logreg_pred", "logreg_prob", "auc_logreg", "cm_lr", "20"),
      XGB = c("xgb_mod", "xgb_pred", "xgb_prob", "auc_xgb", "cm_xgb", "28"))
    prediction <- env[[spec[2]]]; probability <- env[[spec[3]]]; truth <- env$y_test
    samples <- rownames(env$X_test)
    # Retain source objects first, before diagnostics, without renaming probabilities.
    evidence <- list(model = env[[spec[1]]], prediction = prediction, probability = probability,
      truth = truth, sample_ids = samples, feature_ids = colnames(env$X_train),
      source_auc = env[[spec[4]]], rng_after_source = last_source_seed)
    state$model_files[[label]] <<- list(evidence_sha256 = ml_check_evidence_readback(
      evidence, file.path("faithful", paste0(label, "_evidence.rds")), sha))
    diagnostic <- manuscript_probability_diagnostic(probability, samples, levels(truth))
    saveRDS(diagnostic, file.path("diagnostics", paste0(label, "_probability_alignment.rds")))
    state$diagnostics[[label]] <<- diagnostic
    metrics <- manuscript_confusion_metrics(prediction, truth)
    cm <- caret::confusionMatrix(prediction, truth)
    assert(isTRUE(all.equal(unname(cm$overall["Accuracy"]), metrics$accuracy)), "Accuracy validation failed")
    assert(isTRUE(all.equal(unname(cm$byClass[, "F1"]), unname(metrics$per_class_f1))), "Macro F1 validation failed")
    # Additional exports reuse saved predictions, never refit. Use source positional
    # AUC values unchanged; class_names reflects RF columns (factor order if RF failed).
    env[[spec[5]]] <- cm
    env$class_names <- if (exists("rf_prob", env, inherits = FALSE)) colnames(env$rf_prob) else levels(truth)
    auc_name <- switch(label, RF="auc_vals_rf", SVM="auc_vals_svm", LR="auc_vals_lr", XGB="auc_vals_xgb")
    env[[auc_name]] <- unname(env[[spec[4]]])
    previous <- getwd(); setwd("faithful"); on.exit(setwd(previous), add = TRUE)
    eval(parse(text = export_cells[[spec[6]]]), envir = env)
    prefix <- paste0(label, "_")
    csv_paths <- paste0(prefix, c("confusion_matrix.csv", "per_class_metrics.csv", "per_class_auc.csv"))
    for (path in csv_paths) assert(file.exists(path) && file.info(path)$size > 0, "Missing source export")
    auc_read <- read.csv(csv_paths[3], row.names = 1, check.names = FALSE)
    assert(identical(auc_read$Class, env$class_names) &&
      isTRUE(all.equal(auc_read$ROC_AUC, unname(env[[spec[4]]]), tolerance = 1e-12)), "AUC export read-back failed")
    for (entry in list(list(path=csv_paths[1], value=cm$table), list(path=csv_paths[2], value=cm$byClass))) {
      manuscript_check_metric_csv(entry$path, entry$value)
    }
    summary_rows[[label]] <<- data.frame(model = label, accuracy = metrics$accuracy, macro_f1 = metrics$macro_f1)
    historical <- switch(label, RF=c(80/81,.9805097), SVM=c(80/81,.9805097),
      LR=c(78/81,.9248918), XGB=c(79/81,.9698322))
    expected_confusion <- switch(label,
      RF=matrix(c(11,0,0,1, 0,48,0,0, 0,0,7,0, 0,0,0,14),4),
      SVM=matrix(c(11,0,0,1, 0,48,0,0, 0,0,7,0, 0,0,0,14),4),
      LR=matrix(c(10,0,1,1, 0,48,0,0, 0,0,6,1, 0,0,0,14),4),
      XGB=matrix(c(11,0,0,1, 0,47,0,1, 0,0,7,0, 0,0,0,14),4))
    expected_auc <- switch(label, RF=c(.9818841,1,1,.9978678),
      SVM=c(.7934783,.9772727,.7239382,.7857143), LR=c(.9263285,1,.9980695,.9861407),
      XGB=c(.9794686,1,1,.9904051))
    state$comparisons[[label]] <<- list(
      accuracy_and_macro_f1 = if (abs(metrics$accuracy - historical[1]) < 1e-12 &&
        abs(metrics$macro_f1 - historical[2]) < 5e-8) "matches_available_checkpoint" else "differs_from_checkpoint",
      confusion = if (identical(as.numeric(metrics$confusion), as.numeric(expected_confusion)))
        "matches_available_checkpoint" else "differs_from_checkpoint",
      positional_source_auc = if (isTRUE(all.equal(unname(env[[spec[4]]]), expected_auc, tolerance=5e-8, scale=1)))
        "matches_available_checkpoint" else "differs_from_checkpoint")
    # Probability alignment is a separate diagnostic, never a repaired source metric.
  }
  caught <- tryCatch(withCallingHandlers({
    lock <- renv::lockfile_read(file.path(root, "renv.lock"))
    extension <- renv::lockfile_read(ml_lock_path)
    assert(length(lock$Packages) == 113L, "Unexpected baseline lock")
    retained <- renv::lockfile_read(retained_lock_path)
    for (p in names(lock$Packages)) assert(identical(lock$Packages[[p]], retained$Packages[[p]]),
      paste("Retained Manu lock changed baseline record:", p))
    for (p in names(retained$Packages)) assert(identical(retained$Packages[[p]], extension$Packages[[p]]),
      paste("Manuscript lock changed retained Manu record:", p))
    assert(identical(retained$R, extension$R) && identical(retained$Bioconductor, extension$Bioconductor),
      "Manuscript lock changed retained environment metadata")
    state$retained_manu_lock <- list(path=retained_lock_path, sha256=sha(retained_lock_path))
    for (p in names(lock$Packages)) assert(identical(lock$Packages[[p]], extension$Packages[[p]]),
      paste("ML lock changed baseline record:", p))
    assert(identical(lock$R, extension$R) && identical(lock$Bioconductor, extension$Bioconductor),
      "ML lock changed baseline R/repositories/Bioconductor")
    direct <- c("randomForest", "caret", "pROC", "e1071", "nnet", "xgboost")
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
      "scripts/baseline/manuscript-ml.R", "scripts/baseline/ml-support.R", "scripts/baseline/manuscript-ml-support.R",
      "docs/baseline-result-reconciliation.md")
    state$source_hashes <- setNames(vapply(file.path(root, pinned), sha, ""), pinned)
    assert(sha(notebook_path) == "24f7b02dd302afc48d695fdf7cb6b26968edd6b4b63212c28d33d2a3c6f6c1a1", "Recovered notebook hash mismatch")
    api_review <- jsonlite::read_json(api_review_path, simplifyVector = TRUE)
    manuscript_check_xgboost_review(api_review, extension$Packages$xgboost$Version)
    state$xgboost_review <- list(path = api_review_path, sha256 = sha(api_review_path), record = api_review)
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
    assert(identical(state$preprocessing$status, "completed"), "Upstream preprocessing is incomplete")
    panel <- read.csv(paths[4], colClasses = "character", check.names = FALSE)
    info <- read.csv(paths[5], colClasses = "character", check.names = FALSE)
    assert(identical(names(panel), "Gene") && "Gene" %in% names(info), "Panel schema mismatch")
    genes <- panel$Gene
    assert(identical(dim(expr), c(279L, 25750L)) && is.numeric(expr) && all(is.finite(expr)) &&
      ids(rownames(expr)) && ids(colnames(expr)), "Expression schema mismatch")
    assert(nrow(metadata) == 279L &&
      identical(names(metadata), c("batch", "Subtype")) && is.factor(metadata$batch) &&
      !is.ordered(metadata$batch) && !anyNA(metadata$batch) &&
      identical(levels(metadata$batch), c("GSE243375", "GSE52194", "GSE58135")) &&
      is.factor(metadata$Subtype) && !is.ordered(metadata$Subtype) &&
      identical(levels(metadata$Subtype), c("Normal", "ERpos", "TNBC", "HER2pos")) &&
      identical(as.integer(table(metadata$Subtype)), c(26L,42L,48L,163L)), "Metadata schema/order mismatch")
    assert(ids(genes) && length(genes) == 350L && identical(genes, info$Gene) &&
      all(genes %in% colnames(expr)), "Panel identity/order mismatch")
    dir.create("faithful"); dir.create("diagnostics"); dir.create("source_cells")
    # This assertion/mapping replaces only cell 68's unsafe positional CSV bridge.
    bridge_diagnostic <- list(sample_ids_identical = identical(rownames(metadata), rownames(expr)),
      original_sample_ids = rownames(metadata), expression_sample_ids = rownames(expr),
      category_mapping = c(Normal="Normal", ERpos="ER+", TNBC="TNBC", HER2pos="HER2+"))
    saveRDS(bridge_diagnostic, "diagnostics/input_bridge.rds")
    env$metadata <- manuscript_category_bridge(metadata, rownames(expr))
    env$expr <- as.data.frame(expr, optional = TRUE)
    assert(identical(colnames(env$expr), colnames(expr)), "Feature names changed during bridge")
    env$final_hub_genes <- genes
    write.csv(data.frame(original = genes, bridge = colnames(env$expr)[match(genes, colnames(expr))]),
      "diagnostics/feature_name_mapping.csv", row.names = FALSE)
    roundtrip(list(expression_panel = env$expr[, genes, drop = FALSE], metadata = env$metadata), "faithful/input_bridge.rds")
    rm(expr, metadata)
    notebook <- jsonlite::fromJSON(notebook_path, simplifyVector = FALSE)
    for (cell in names(cell_hashes)) {
      text <- paste0(unlist(notebook$cells[[as.integer(cell)]]$source), collapse = "")
      path <- file.path("source_cells", paste0(cell, ".R"))
      cat(text, file = path)
      assert(sha(path) == cell_hashes[[cell]], paste("Recovered cell hash mismatch:", cell))
      if (cell %in% names(cells)) assert(identical(text, cells[[cell]]), paste("Verbatim source mismatch:", cell))
    }
    state$notebook <- list(path = notebook_path, sha256 = sha(notebook_path), cells = cell_hashes,
      bridge_adaptation = "68 not executed: pinned RDS/CSV bridge with explicit identity diagnostic; readr not needed")
    # Original attachment order after omitting unused readr CSV loader. All loads
    # and formals inspection precede the sole seed reset, in cell 70.
    eval(quote({ library(dplyr); library(caret); library(randomForest); library(e1071)
      library(nnet); library(xgboost); library(pROC); library(ggplot2) }), envir = env)
    defaults <- lapply(c("randomForest", "svm", "multinom", "xgboost", "roc", "createDataPartition"), function(n) {
      f <- get(n, envir = env, mode = "function")
      list(name = n, environment = environmentName(environment(f)), formals = formals(f))
    })
    defaults$methods <- list(randomForest = formals(randomForest:::randomForest.default),
      svm = formals(e1071:::svm.default), multinom = formals(nnet::multinom),
      roc = formals(pROC:::roc.default))
    saveRDS(defaults, "effective_defaults.rds")
    state$models <- as.list(setNames(rep("not_reached", 4), c("RF", "SVM", "LR", "XGB")))
    for (cell in names(cells)) {
      stage <- paste0("cell_", cell)
      state$stages[[stage]] <- list(status = "started", utc = utc(), rng_before = seed())
      cat("STAGE", stage, "started", utc(), "\n"); flush(log); persist()
      evaluate <- function() {
        # Also retain RNG consumed by a failed branch, without reseeding later fits.
        on.exit({ last_source_seed <<- seed(); state$stages[[stage]]$rng_after_source <<- seed() }, add = TRUE)
        eval(parse(text = cells[[cell]], keep.source = TRUE), envir = env)
      }
      validate <- function() {
        if (cell == "69") return(invisible(NULL))
        if (cell == "70") {
          assert(identical(levels(env$y), c("ER+", "HER2+", "Normal", "TNBC")), "Unexpected source category order")
          assert(identical(dim(env$X), c(279L,350L)) && identical(colnames(env$X), genes), "Panel order/dimensions changed")
          roundtrip(list(indices = env$train_idx, train_samples = rownames(env$X_train),
            test_samples = rownames(env$X_test), truth_train = env$y_train, truth_test = env$y_test,
            feature_names = colnames(env$X_train), rng_after_split = last_source_seed), "faithful/split.rds")
          state$comparisons$split <<- if (nrow(env$X_train) == 198L && nrow(env$X_test) == 81L &&
            identical(as.integer(table(env$y_train)), c(30L,115L,19L,34L)) &&
            identical(as.integer(table(env$y_test)), c(12L,48L,7L,14L)))
            "matches_available_checkpoint" else "differs_from_checkpoint"
        } else capture_model(unname(model_for_cell[[cell]]))
        # Diagnostics/read-backs must not perturb the next model's RNG stream.
        ml_assert_rng(last_source_seed, seed())
      }
      if (cell %in% names(model_for_cell)) {
        result <- ml_run_branch(evaluate, validate,
          precheck = function() ml_assert_rng(last_source_seed, seed()))
        label <- unname(model_for_cell[[cell]])
        state$models[[label]] <- result$status
        state$stages[[stage]]$branch_result <- result
        state$stages[[stage]]$status <- result$status
        if (result$status != "succeeded") state$comparisons[[label]] <- "not_verifiable"
      } else {
        ml_run_preparation(evaluate, validate)
        state$stages[[stage]]$status <- "succeeded"
      }
      state$stages[[stage]]$rng_after <- seed()
      cat("STAGE", stage, state$stages[[stage]]$status, utc(), "\n"); flush(log); persist()
    }
    state$workflow_status <- ml_workflow_status(state$models)
    stage <- "summary"
    # Measured summary only; no hard-coded cell-2 bar heights and no new fits.
    if (length(summary_rows)) {
      summary <- do.call(rbind, summary_rows)
      write.csv(summary, "faithful/model_summary.csv", row.names = FALSE)
      png("faithful/model_comparison.png", 2000, 1600, res = 200)
      barplot(t(as.matrix(summary[, c("accuracy", "macro_f1")])), beside = TRUE,
        names.arg = summary$model, ylim = c(0,1), col = c("red", "cyan"),
        ylab = "Score", main = "Manuscript replay: measured completed models")
      abline(h = .25, col = "red", lty = 2)
      legend("bottomright", legend = c("Accuracy", "Macro F1", "Uniform random guess"),
        fill = c("red", "cyan", NA), lty = c(NA, NA, 2))
      dev.off()
    }
    NULL
  }, warning = function(w) {
    state$warnings[[length(state$warnings) + 1L]] <<- list(stage = stage, text = conditionMessage(w), call = deparse(conditionCall(w)))
    cat("WARNING", conditionMessage(w), "\n"); flush(log)
  }, message = function(m) {
    state$messages[[length(state$messages) + 1L]] <<- list(stage = stage, text = conditionMessage(m))
    cat("MESSAGE", conditionMessage(m), "\n"); flush(log)
  }), error = function(e) {
    state$error <<- list(stage = stage, text = conditionMessage(e), call = deparse(conditionCall(e)))
    state$workflow_status <<- if (stage == "preflight") "preflight_blocked" else
      if (stage %in% c("cell_69", "cell_70")) "finished_with_preparation_failure" else "wrapper_failed"
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
      diagnostic_status = if (length(state$diagnostics) == 4L &&
        all(vapply(state$diagnostics, function(x) x$dimensions_match &&
          x$row_alignment == "aligned" && x$column_alignment == "aligned" &&
          x$finite_probabilities && x$normalized_rows, logical(1)))) "aligned" else "review_required",
      probability_diagnostics = state$diagnostics,
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

cell_hashes <- c(
  `68` = "e42d1230e49eaec4131ebe2cf647c98167fd937eab339889caac9128526444f9",
  `69` = "760896b94616842773aa1075a7893f5c4c3c9cec78205e33efa7576c6dbd8e2e",
  `70` = "6008f341a1d62e766a034e7a2d715160ffba80622bd15b3a8765a3f7b8833d23",
  `71` = "c1571e35ca43ef15109755c914aa9bba56531a7f1fec6270195ebdb36f4dbdd1",
  `72` = "78326881d8ce0820bea9095527742ce3a47c63e51fd0b13e7d70c87f5db14632",
  `73` = "c5b3792f77bde7a6d16732ee8c7af142edc605a95431095f4da91d9a015c39ff",
  `74` = "433bd46aaf962f93dbdec1d9ef8f57617049a50fdba0585e0dda9d7a84e4d53d",
  `8` = "29d0f7fc8503c3db53aac639aaf607c6b8cd4aa3d1429cc4b68527a2df49dfef",
  `13` = "1206c236332bf369f0eaa6aa946a54b2924509def525c43b74119434c9591ca2",
  `20` = "d1bd69037a431d62b44f4fc02727593f4e9865236d356e14d2e625f744717401",
  `28` = "12e1f4104c8f7238d2ae024aa822a35041150ce6518cec0ca76277421344faed"
)
cells <- list(
  `69` = r"---(stopifnot(all(rownames(expr) == rownames(metadata)))
stopifnot(all(final_hub_genes %in% colnames(expr)))
cat("expr:", dim(expr), " | metadata:", dim(metadata), "\n")
cat("First 5 hub genes:", head(final_hub_genes), "\n"))---",
  `70` = r"---(# 3. Subset to hub genes and define labels
X <- expr[, final_hub_genes]
y <- as.factor(metadata$category)

# 4. Stratified split (caret)
set.seed(2024)
train_idx <- createDataPartition(y, p = 0.7, list = FALSE)
X_train <- X[train_idx, ]; X_test <- X[-train_idx, ]
y_train <- y[train_idx];   y_test <- y[-train_idx]

cat("Train:", dim(X_train), "| Test:", dim(X_test), "\n")
print(table(y_train)); print(table(y_test)))---",
  `71` = r"---(# 5. Fit Random Forest
rf <- randomForest(x = X_train, y = y_train, ntree = 1000, importance = TRUE)
rf_pred <- predict(rf, X_test)
rf_prob <- predict(rf, X_test, type = "prob")
cat("\nRandom Forest:\n")
print(confusionMatrix(rf_pred, y_test))

# 6. Per-class ROC-AUC
y_test_bin <- model.matrix(~ y_test - 1)
auc_rf <- sapply(seq_along(levels(y_test)), function(i) {
  roc(y_test_bin[, i], rf_prob[, i])$auc
})
names(auc_rf) <- levels(y_test)
print(auc_rf))---",
  `72` = r"---(# 7. SVM (RBF kernel)
svm_mod <- svm(x = X_train, y = y_train, kernel = "radial", probability = TRUE)
svm_pred <- predict(svm_mod, X_test)
svm_prob <- attr(predict(svm_mod, X_test, probability = TRUE), "probabilities")
cat("\nSVM (RBF):\n")
print(confusionMatrix(svm_pred, y_test))
auc_svm <- sapply(seq_along(levels(y_test)), function(i) {
  roc(y_test_bin[, i], svm_prob[, i])$auc
})
names(auc_svm) <- levels(y_test)
print(auc_svm))---",
  `73` = r"---(# 8. Multinomial Logistic Regression
logreg <- multinom(y_train ~ ., data = as.data.frame(X_train), trace = FALSE, MaxNWts = 5000)
logreg_pred <- predict(logreg, X_test)
logreg_prob <- predict(logreg, X_test, type = "probs")
cat("\nMultinomial Logistic Regression:\n")
print(confusionMatrix(logreg_pred, y_test))
auc_logreg <- sapply(seq_along(levels(y_test)), function(i) {
  roc(y_test_bin[, i], logreg_prob[, i])$auc
})
names(auc_logreg) <- levels(y_test)
print(auc_logreg))---",
  `74` = r"---(# 9. XGBoost (multi-class)
X_train_mat <- as.matrix(X_train)
X_test_mat  <- as.matrix(X_test)
y_train_int <- as.integer(y_train) - 1
y_test_int  <- as.integer(y_test) - 1

xgb_mod <- xgboost(
  data = X_train_mat, label = y_train_int,
  objective = "multi:softprob", num_class = length(levels(y_train)),
  nrounds = 100, max_depth = 6, eta = 0.1, verbose = 0
)
xgb_prob <- matrix(predict(xgb_mod, X_test_mat), ncol = length(levels(y_train)), byrow = TRUE)
xgb_pred <- factor(levels(y_train)[max.col(xgb_prob)], levels = levels(y_train))
cat("\nXGBoost:\n")
print(confusionMatrix(xgb_pred, y_test))
auc_xgb <- sapply(seq_along(levels(y_test)), function(i) {
  roc(y_test_bin[, i], xgb_prob[, i])$auc
})
names(auc_xgb) <- levels(y_test)
print(auc_xgb))---"
)
export_cells <- list(
  `8` = r"---(write.csv(cm_rf$table, "RF_confusion_matrix.csv")
write.csv(cm_rf$byClass, "RF_per_class_metrics.csv")
write.csv(data.frame(Class = class_names, ROC_AUC = auc_vals_rf), "RF_per_class_auc.csv"))---",
  `13` = r"---(write.csv(cm_svm$table, "SVM_confusion_matrix.csv")
write.csv(cm_svm$byClass, "SVM_per_class_metrics.csv")
write.csv(data.frame(Class = class_names, ROC_AUC = auc_vals_svm), "SVM_per_class_auc.csv"))---",
  `20` = r"---(write.csv(cm_lr$table, "LR_confusion_matrix.csv")
write.csv(cm_lr$byClass, "LR_per_class_metrics.csv")
write.csv(data.frame(Class = class_names, ROC_AUC = auc_vals_lr), "LR_per_class_auc.csv"))---",
  `28` = r"---(write.csv(cm_xgb$table, "XGB_confusion_matrix.csv")
write.csv(cm_xgb$byClass, "XGB_per_class_metrics.csv")
write.csv(data.frame(Class = class_names, ROC_AUC = auc_vals_xgb), "XGB_per_class_auc.csv"))---"
)
quit(status = main(), save = "no")
