# Branch-specific checks; no training, package loads or RNG changes.
manuscript_category_bridge <- function(metadata, samples) {
  if (!identical(rownames(metadata), samples))
    stop("Metadata/sample identity or order mismatch; no positional repair", call. = FALSE)
  map <- c(Normal = "Normal", ERpos = "ER+", TNBC = "TNBC", HER2pos = "HER2+")
  category <- unname(map[as.character(metadata$Subtype)])
  if (anyNA(category)) stop("Unknown category in bridge", call. = FALSE)
  data.frame(category = category, batch = as.character(metadata$batch),
    row.names = samples, stringsAsFactors = FALSE)
}
manuscript_probability_diagnostic <- function(probability, samples, classes) {
  supported <- is.matrix(probability) || is.data.frame(probability)
  matrix <- if (supported) as.matrix(probability) else NULL
  list(original_class = class(probability), dimensions = dim(probability),
    dimensions_match = supported && identical(dim(probability), c(length(samples), length(classes))),
    row_alignment = if (is.null(rownames(probability))) "unlabelled_not_verifiable" else
      if (identical(rownames(probability), samples)) "aligned" else "mismatch",
    column_alignment = if (is.null(colnames(probability))) "unlabelled_not_verifiable" else
      if (identical(colnames(probability), classes)) "aligned" else "mismatch",
    original_columns = colnames(probability), expected_columns = classes,
    finite_probabilities = supported && is.numeric(matrix) && all(is.finite(matrix)) &&
      all(matrix >= 0 & matrix <= 1),
    normalized_rows = supported && is.numeric(matrix) && all(is.finite(matrix)) &&
      all(abs(rowSums(matrix) - 1) < 1e-6),
    action = "Diagnostic only: no relabelling, reordering or alternate AUC calculation")
}
manuscript_confusion_metrics <- function(prediction, truth) {
  if (length(prediction) != length(truth) || anyNA(prediction) ||
      !all(as.character(prediction) %in% levels(truth))) stop("Invalid predictions", call. = FALSE)
  cm <- table(factor(prediction, levels = levels(truth)), truth)
  denom <- rowSums(cm) + colSums(cm)
  f1 <- 2 * diag(cm) / denom
  list(confusion = cm, accuracy = sum(diag(cm)) / sum(cm),
    per_class_f1 = f1, macro_f1 = mean(f1))
}
manuscript_check_xgboost_review <- function(review, version) {
  fields <- c("version", "source_sha256", "assessment", "prediction_contract", "reviewer")
  if (!all(fields %in% names(review)) ||
      !all(vapply(review[fields], function(x) is.character(x) && length(x) == 1L && !is.na(x), logical(1))) ||
      !identical(review$version, version) ||
      !grepl("^[0-9a-f]{64}$", review$source_sha256) ||
      !identical(review$assessment, "verbatim_api_compatible") ||
      !identical(review$prediction_contract, "flat_row_major_multiclass_probability_vector") ||
      !nzchar(trimws(review$reviewer)))
    stop("Review exact XGBoost source/API compatibility before execution; no automatic version choice", call. = FALSE)
  invisible(TRUE)
}
manuscript_check_metric_csv <- function(path, expected) {
  read <- read.csv(path, row.names = 1, check.names = FALSE)
  # A table's class attribute is not a CSV payload. Check labels/dimensions
  # explicitly, then compare numeric values (including any matching NAs).
  if (!identical(dim(read), dim(expected)) || !identical(rownames(read), rownames(expected)) ||
      !identical(colnames(read), colnames(expected)) ||
      !isTRUE(all.equal(as.numeric(as.matrix(read)), as.numeric(expected), tolerance = 1e-12)))
    stop("Metrics export read-back failed: ", path, call. = FALSE)
  invisible(TRUE)
}
