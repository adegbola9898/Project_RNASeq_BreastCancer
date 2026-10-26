# Pure/branch helpers; sourcing definitions does not fit models or load ML packages.
ml_probability_matrix <- function(probability, samples, classes) {
  if (!(is.matrix(probability) || is.data.frame(probability)) ||
      !identical(rownames(probability), samples) ||
      !identical(dim(probability), c(length(samples), length(classes))) ||
      anyDuplicated(colnames(probability)) || !setequal(colnames(probability), classes))
    stop("Invalid probability dimensions, labels or row alignment", call. = FALSE)
  # Validate a copy; the original data frame/matrix is retained in evidence.
  matrix <- as.matrix(probability)
  if (!is.numeric(matrix) || any(!is.finite(matrix)) ||
      any(matrix < 0 | matrix > 1) || any(abs(rowSums(matrix) - 1) >= 1e-6))
    stop("Invalid probability values", call. = FALSE)
  matrix
}
ml_auc_matches <- function(x) {
  is.numeric(x) && length(x) > 0L && all(is.finite(x)) && all(signif(x, 7L) == 1)
}
ml_assert_rng <- function(after_split, before_rf) {
  if (is.null(after_split) || !identical(after_split, before_rf))
    stop("RNG state changed between split and RF", call. = FALSE)
  invisible(TRUE)
}
ml_run_branch <- function(evaluate, validate, precheck = function() NULL,
                          close_devices = grDevices::graphics.off) {
  result <- list(status = "not_reached", training_status = "not_reached",
    validation_status = "not_reached", errors = list())
  phase <- "precheck"
  tryCatch({
    precheck()
    phase <- "training"
    evaluate()
    result$training_status <- "succeeded"
    phase <- "validation"
    validate()
    result$validation_status <- "succeeded"
    result$status <- "succeeded"
  }, error = function(e) {
    result$status <<- if (phase == "training") "training_failed" else "validation_failed"
    if (phase == "training") result$training_status <<- "failed" else result$validation_status <<- "failed"
    result$errors[[length(result$errors) + 1L]] <<- list(phase = phase,
      text = conditionMessage(e), call = deparse(conditionCall(e)))
  })
  # Close even after a failed source call/validation; never skip the next branch.
  tryCatch(close_devices(), error = function(e) {
    result$status <<- "validation_failed"
    result$validation_status <<- "failed"
    result$errors[[length(result$errors) + 1L]] <<- list(phase = "graphics_finalisation",
      text = conditionMessage(e), call = deparse(conditionCall(e)))
  })
  result
}
ml_run_preparation <- function(evaluate, validate) {
  evaluate()
  validate()
  invisible(NULL)
}
ml_workflow_status <- function(models) {
  if (all(unlist(models) == "succeeded")) "finished_all_models_succeeded" else "finished_with_model_failure"
}
# Environment-free view of a model object, for read-back comparison only; never
# applied to saved objects. Environments/external pointers become placeholders, so
# captured frames (e.g. formulas built inside fitting helpers) are not compared by
# identity. Language/functions are compared by attribute-preserving deparse;
# every other value and attribute is compared exactly.
ml_environment_free <- function(x) {
  if (is.environment(x)) return(list(.ml = "environment"))
  if (typeof(x) == "externalptr") return(list(.ml = "externalptr"))
  if (is.language(x) || is.function(x) || (is.pairlist(x) && !is.null(x)))
    return(list(.ml = typeof(x), text = deparse(x, control = c("keepNA", "keepInteger",
      "niceNames", "showAttributes", "digits17"))))
  attrs <- attributes(x)
  value <- if (is.list(x)) lapply(unclass(x), ml_environment_free) else if (isS4(x)) NULL else {
    v <- unclass(x); attributes(v) <- NULL; v
  }
  list(.ml = typeof(x), value = value,
    attributes = if (is.null(attrs)) NULL else lapply(attrs, ml_environment_free))
}
ml_model_readback_equal <- function(original, loaded) {
  identical(ml_environment_free(original), ml_environment_free(loaded))
}
# Evidence other than the model is environment-free output and stays strictly identical().
ml_evidence_equal <- function(evidence, loaded) {
  identical(names(loaded), names(evidence)) &&
    identical(evidence[names(evidence) != "model"], loaded[names(loaded) != "model"]) &&
    ml_model_readback_equal(evidence$model, loaded$model)
}
ml_check_evidence_readback <- function(evidence, path, hash) {
  saveRDS(evidence, path)
  if (!ml_evidence_equal(evidence, readRDS(path))) stop("Read-back failed: ", path, call. = FALSE)
  hash(path)
}
# Source checkpoint: model compared environment-free; other saved objects strictly.
ml_check_checkpoint <- function(path, expected, model_name, hash) {
  loaded <- new.env(parent = emptyenv())
  if (!setequal(load(path, envir = loaded), names(expected)))
    stop("Checkpoint objects differ", call. = FALSE)
  for (n in names(expected)) {
    same <- if (n == model_name) ml_model_readback_equal(expected[[n]], loaded[[n]]) else
      identical(expected[[n]], loaded[[n]])
    if (!same) stop("Checkpoint read-back: ", n, call. = FALSE)
  }
  hash(path)
}
ml_outer_failure_status <- function(stage) {
  if (stage == "preflight") "preflight_blocked" else
    if (stage %in% c("cell_55", "cell_57")) "finished_with_preparation_failure" else "wrapper_failed"
}
