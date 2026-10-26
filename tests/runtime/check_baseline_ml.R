# Small base-R fixtures. No runner/main execution, ML packages or model fitting.
source("scripts/baseline/ml-support.R", local = TRUE)
fail_expected <- function(expr) stopifnot(inherits(tryCatch({ force(expr); NULL }, error = identity), "error"))
scratch <- tempfile("ml-fixtures-"); dir.create(scratch)
cat("Scratch:", scratch, "\n")
runner <- parse("scripts/baseline/ml.R")
main_assignment <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
  identical(x[[2]], as.name("main")), as.list(runner))
stopifnot(length(main_assignment) == 1L)
main_body <- as.list(main_assignment[[1L]][[3L]][[3L]])
# Extract actual main assignments only, never evaluate main or the source cells.
assignment <- function(name) {
  found <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
    identical(x[[2]], as.name(name)), main_body)
  stopifnot(length(found) == 1L); found[[1L]]
}
local({
  private_wrapper_state <- new.env()
  env <- NULL
  eval(assignment("env"))
  stopifnot(identical(env, .GlobalEnv))
  eval(quote(.ml_fixture_formula <- response ~ feature), envir = env)
  on.exit(rm(".ml_fixture_formula", envir = .GlobalEnv), add = TRUE)
  model <- list(terms = terms(env$.ml_fixture_formula))  # formula metadata only
  assert <- function(ok, message) if (!isTRUE(ok)) stop(message)
  eval(assignment("roundtrip"))
  roundtrip(model, file.path(scratch, "formula.rds"))
  stopifnot(identical(attr(model$terms, ".Environment"), .GlobalEnv))
  save(model, file = file.path(scratch, "formula.RData"))
  loaded <- new.env(parent = emptyenv()); load(file.path(scratch, "formula.RData"), loaded)
  stopifnot(identical(model, loaded$model), identical(attr(loaded$model$terms, ".Environment"), .GlobalEnv))
})
cat("PASS serialization: actual global evaluation binding; formula terms RDS/RData identity\n")
p <- data.frame(A = c(.2,.8), B = c(.8,.2), row.names = c("s1","s2"))
original <- p
m <- ml_probability_matrix(p, c("s1","s2"), c("A","B"))
stopifnot(is.matrix(m), identical(p, original), identical(ml_probability_matrix(m, rownames(m), colnames(m)), m))
fail_expected(ml_probability_matrix(p[2:1,], rownames(p), names(p)))
fail_expected(ml_probability_matrix(p, rownames(p), c("A","C")))
fail_expected(ml_probability_matrix(p[1,,drop=FALSE], rownames(p), names(p)))
bad <- p; bad[1,1] <- NA; fail_expected(ml_probability_matrix(bad, rownames(p), names(p)))
cat("PASS probabilities: data frame and matrix, preserved original, rows/labels/dimensions/values\n")
stopifnot(ml_auc_matches(c(1,1)), !ml_auc_matches(.9996), !ml_auc_matches(.9999999),
  ml_auc_matches(.99999999), !ml_auc_matches(NA_real_))
cat("PASS AUC: seven significant digits, including 0.9996 regression\n")
closed <- 0L; reached <- character()
results <- list()
for (label in c("RF", "SVM", "logistic")) {
  results[[label]] <- ml_run_branch(function() {
    reached <<- c(reached, label)
    if (label == "RF") stop("synthetic source failure")
  }, function() { if (label == "SVM") stop("synthetic evidence failure") },
  close_devices = function() { closed <<- closed + 1L })
}
stopifnot(identical(reached, c("RF","SVM","logistic")), closed == 3L,
  results$RF$status == "training_failed", results$RF$validation_status == "not_reached",
  results$SVM$status == "validation_failed", results$SVM$training_status == "succeeded",
  results$logistic$status == "succeeded",
  ml_workflow_status(lapply(results, `[[`, "status")) == "finished_with_model_failure",
  ml_workflow_status(list(RF="succeeded",SVM="succeeded",logistic="succeeded")) == "finished_all_models_succeeded")
grDevices::pdf(file.path(scratch, "failure-device.pdf"))
real_cleanup <- ml_run_branch(function() stop("device open on failure"), function() NULL)
stopifnot(real_cleanup$status == "training_failed", is.null(grDevices::dev.list()))
cleanup <- ml_run_branch(function() NULL, function() NULL,
  close_devices = function() stop("synthetic close failure"))
stopifnot(cleanup$status == "validation_failed", cleanup$errors[[1]]$phase == "graphics_finalisation")
for (stage in c("cell_55", "cell_57")) {
  attempted <- FALSE
  fail_expected({ ml_run_preparation(function() stop("preparation failed"), function() NULL); attempted <- TRUE })
  stopifnot(!attempted, ml_outer_failure_status(stage) == "finished_with_preparation_failure")
}
stopifnot(ml_outer_failure_status("preflight") == "preflight_blocked",
  ml_outer_failure_status("cell_58") == "wrapper_failed")
cat("PASS branches: training vs validation failure, continuation, graphics cleanup, preparation stop, workflow mapping\n")
ml_assert_rng(1:4, 1:4); fail_expected(ml_assert_rng(1:4, 2:5))
started <- FALSE
r <- ml_run_branch(function() { started <<- TRUE }, function() NULL,
  precheck = function() ml_assert_rng(1:4, 2:5), close_devices = function() NULL)
stopifnot(!started, r$status == "validation_failed", r$training_status == "not_reached")
cat("PASS RNG: unchanged accepted, altered rejected before RF branch execution\n")
planner <- parse("scripts/baseline/ml-dependency-plan.R")
eval(planner[[1L]])  # pure resolver definition only; never run CLI
metadata <- matrix(NA_character_, 6L, 5L, dimnames = list(
 c("randomForest","caret","pROC","e1071","helper","MASS"),
 c("Package","Version","Depends","Imports","LinkingTo")))
metadata[,"Package"] <- rownames(metadata); metadata[,"Version"] <- "1.0"
metadata["caret","Imports"] <- "helper (>= 1.0), retained (>= 2.0), MASS"
metadata["helper","Depends"] <- "R (>= 4.0), base"
resolved <- ml_resolve_dependencies(metadata, c(retained="2.0"), c(base="4.5.2"), "4.5.2")
stopifnot(setequal(names(resolved$additions), rownames(metadata)), !"retained" %in% names(resolved$additions))
conflict <- metadata; conflict["caret","Imports"] <- "retained (>= 3.0)"
fail_expected(ml_resolve_dependencies(conflict, c(retained="2.0"), c(base="4.5.2"), "4.5.2"))
conflict <- metadata; conflict["helper","Depends"] <- "R (>= 9.0)"
fail_expected(ml_resolve_dependencies(conflict, c(retained="2.0"), c(base="4.5.2"), "4.5.2"))
cat("PASS planner: recursive closure, recommended additions, retained version and R conflicts\n")
# caret-like object: outer terms in .GlobalEnv, finalModel terms built inside a fit
# helper whose frame holds data. Structure only; no model fitted.
fit_helper <- function(x, y) {
  dat <- x; dat$.outcome <- y
  list(call = quote(fit(.outcome ~ ., data = dat)), coefficients = c(a = 0.25, b = -1.5),
    terms = terms(.outcome ~ ., data = dat))
}
nested <- structure(list(method = "multinom", bestTune = data.frame(decay = 1e-4),
  terms = terms(Subtype ~ ., data = data.frame(Subtype = factor("x"), g = 1)),
  finalModel = fit_helper(data.frame(a = 1:3, b = 4:6), factor(c("u","v","u")))), class = "train")
stopifnot(!identical(environment(nested$finalModel$terms), .GlobalEnv))
rds <- file.path(scratch, "nested.rds"); saveRDS(nested, rds)
stopifnot(!identical(nested, readRDS(rds)), ml_model_readback_equal(nested, readRDS(rds)))
hash <- function(p) unname(tools::sha256sum(p))
evidence <- list(model = nested, prediction = factor(c(s1 = "u", s2 = "v")),
  probability = data.frame(u = c(.6, .3), v = c(.4, .7), row.names = c("s1", "s2")),
  confusion = table(c("u","v"), c("u","v")), auc = c(u = 1, v = 1))
evidence_path <- file.path(scratch, "nested_evidence.rds")
stopifnot(identical(ml_check_evidence_readback(evidence, evidence_path, hash), hash(evidence_path)))
logreg_mod <- nested; logreg_confmat <- evidence$confusion; auc_list_logreg <- evidence$auc
checkpoint <- file.path(scratch, "logreg_fixture.RData")
save(logreg_mod, logreg_confmat, auc_list_logreg, file = checkpoint)
checkpoint_objects <- list(logreg_mod = logreg_mod, logreg_confmat = logreg_confmat,
  auc_list_logreg = auc_list_logreg)
stopifnot(identical(ml_check_checkpoint(checkpoint, checkpoint_objects, "logreg_mod", hash),
  hash(checkpoint)))
# Each compared model field change must be detected against the saved copy.
mutations <- list(
  coefficient = function(m) { m$finalModel$coefficients[["a"]] <- 0.2500001; m },
  call = function(m) { m$finalModel$call <- quote(fit(.outcome ~ a, data = dat)); m },
  nested_terms = function(m) { m$finalModel$terms <- terms(.outcome ~ a, data = data.frame(.outcome = 1, a = 1)); m },
  tuning = function(m) { m$bestTune$decay <- 0.1; m },
  class = function(m) { class(m) <- "other"; m },
  added_field = function(m) { m$extra <- 1; m })
for (name in names(mutations)) {
  changed <- mutations[[name]](nested)
  if (ml_model_readback_equal(changed, readRDS(rds))) stop("Undetected model change: ", name)
  objects <- checkpoint_objects; objects$logreg_mod <- changed
  fail_expected(ml_check_checkpoint(checkpoint, objects, "logreg_mod", hash))
}
# Environment-free outputs remain strict: one prediction label or probability digit.
strict <- list(prediction = function(e) { e$prediction[2] <- "u"; e },
  probability = function(e) { e$probability$u[1] <- 0.6000000001; e },
  auc = function(e) { e$auc[["v"]] <- 0.9999999; e })
saved_evidence <- readRDS(evidence_path)
stopifnot(ml_evidence_equal(evidence, saved_evidence))
for (name in names(strict))
  if (ml_evidence_equal(strict[[name]](evidence), saved_evidence)) stop("Undetected evidence change: ", name)
for (name in names(mutations)) {
  changed <- evidence; changed$model <- mutations[[name]](nested)
  if (ml_evidence_equal(changed, saved_evidence)) stop("Undetected evidence model change: ", name)
}
objects <- checkpoint_objects; objects$logreg_confmat[1, 1] <- 0L
fail_expected(ml_check_checkpoint(checkpoint, objects, "logreg_mod", hash))
cat("PASS nested formula: identical() fails as expected; environment-free model and strict outputs round-trip; field changes rejected; SHA-256 returned\n")
cat("All seven runtime fixture groups passed; no model fitted.\n")
