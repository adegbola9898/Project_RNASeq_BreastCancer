# New-branch fixtures only; never invoke main() or model-training cells.
source("scripts/baseline/ml-support.R", local = TRUE)
source("scripts/baseline/manuscript-ml-support.R", local = TRUE)
bad <- function(expr) stopifnot(inherits(tryCatch({ force(expr); NULL }, error=identity), "error"))
e <- new.env(parent = .GlobalEnv)
expressions <- parse("scripts/baseline/manuscript-ml.R")
for (expression in expressions) if (is.call(expression) && identical(expression[[1]], as.name("<-")) &&
  as.character(expression[[2]]) %in% c("cells", "cell_hashes", "export_cells")) eval(expression, e)
metadata <- data.frame(Subtype=factor(c("Normal","ERpos","TNBC","HER2pos"),
  levels=c("Normal","ERpos","TNBC","HER2pos")), batch=rep("study",4), row.names=paste0("s",1:4))
mapped <- manuscript_category_bridge(metadata, rownames(metadata))
e$metadata <- mapped; e$expr <- data.frame(`101929498`=1:4, A=5:8, check.names=FALSE)
rownames(e$expr) <- rownames(metadata); e$final_hub_genes <- names(e$expr)
# Actual cell 69 is harmless assertions/prints; cell 70's factor assignment is
# tested separately without invoking caret splitting or training.
eval(parse(text=e$cells[["69"]]), e)
factor_expression <- parse(text=e$cells[["70"]])[[2L]]
eval(factor_expression, e)
stopifnot(identical(levels(e$y),c("ER+","HER2+","Normal","TNBC")),
  identical(names(e$expr),c("101929498","A")), identical(rownames(mapped),rownames(metadata)))
bad(manuscript_category_bridge(metadata[4:1,],rownames(metadata)))
cat("PASS category bridge: by-value mapping, source factor order, preserved raw names and sample identities\n")
p <- matrix(c(.2,.8,.8,.2),2,dimnames=list(c("s1","s2"),c("B","A")))
original <- p
d <- manuscript_probability_diagnostic(p,c("s1","s2"),c("A","B"))
stopifnot(d$column_alignment=="mismatch",identical(original,p),d$row_alignment=="aligned")
u <- p; dimnames(u) <- NULL
d <- manuscript_probability_diagnostic(u,c("s1","s2"),c("A","B"))
stopifnot(d$column_alignment=="unlabelled_not_verifiable",d$row_alignment=="unlabelled_not_verifiable")
cat("PASS probability diagnostics: swapped/unlabelled columns flagged without source repair\n")
# Wrappers/exports between source stages must consume no analytical RNG.
# Synthetic stages use tiny random draws as stand-ins; no model is fitted.
set.seed(2024); expected <- lapply(1:4,function(i) runif(1))
set.seed(2024); previous <- .Random.seed; observed <- list()
for (i in 1:4) {
 result <- ml_run_branch(function() {
   observed[[i]] <<- runif(1); previous <<- .Random.seed
 }, function() {
   manuscript_probability_diagnostic(p,c("s1","s2"),c("A","B"))
   ml_assert_rng(previous,.Random.seed)
 }, precheck=function() ml_assert_rng(previous,.Random.seed),close_devices=function() NULL)
 stopifnot(result$status=="succeeded")
}
stopifnot(identical(expected,observed))
cat("PASS continuing RNG: no wrapper reseeds; synthetic stream matches uninterrupted reference\n")
truth <- factor(c("ER+","HER2+","Normal","TNBC"),levels=c("ER+","HER2+","Normal","TNBC"))
metrics <- manuscript_confusion_metrics(truth,truth)
stopifnot(metrics$accuracy==1,metrics$macro_f1==1)
bad(manuscript_confusion_metrics(truth[-1],truth))
cat("PASS measured metrics from synthetic predictions, no hard-coded bar values\n")
review <- list(version="fixture-version",source_sha256=paste(rep("a",64),collapse=""),
 assessment="verbatim_api_compatible",prediction_contract="flat_row_major_multiclass_probability_vector",reviewer="fixture only")
manuscript_check_xgboost_review(review,"fixture-version")
bad(manuscript_check_xgboost_review(review,"different-version"))
review$prediction_contract <- "matrix"; bad(manuscript_check_xgboost_review(review,"fixture-version"))
cat("PASS XGBoost decision gate: explicit matching review required; matrix-contract claim rejected\n")
# Source export blocks write only tiny synthetic tables in scratch, not models.
scratch <- tempfile("manuscript-export-"); dir.create(scratch)
local({
 previous <- getwd(); setwd(scratch); on.exit(setwd(previous),add=TRUE)
 before_exports <- .Random.seed
 for (i in names(e$export_cells)) {
   label <- switch(i,`8`="rf",`13`="svm",`20`="lr",`28`="xgb")
   e[[paste0("cm_",label)]] <- list(table=metrics$confusion,byClass=matrix(1,4,1,dimnames=list(levels(truth),"F1")))
   e$class_names <- levels(truth); e[[paste0("auc_vals_",label)]] <- rep(1,4)
   eval(parse(text=e$export_cells[[i]]),e)
 }
 stopifnot(length(list.files(pattern="csv$"))==12,identical(before_exports,.Random.seed))
 manuscript_check_metric_csv("RF_confusion_matrix.csv",metrics$confusion)
 modified <- metrics$confusion; modified[1,1] <- 999
 bad(manuscript_check_metric_csv("RF_confusion_matrix.csv",modified))
})
cat("PASS four verbatim export blocks: 12 tiny CSVs, no fits\n")
# Exercise the runner's actual source evaluator with synthetic failing cells:
# consumed RNG survives a failure and is continued, never reset for another model.
main_assignment <- Filter(function(x) is.call(x) && identical(x[[1]],as.name("<-")) &&
  identical(x[[2]],as.name("main")),as.list(expressions))[[1]]
main_statements <- as.list(main_assignment[[3]][[3]])
nested_calls <- function(tree) {
 out <- list()
 walk <- function(x) {
   if (is.call(x)) out[[length(out)+1L]] <<- x
   if (is.call(x) || is.expression(x)) for (i in seq_along(x)) {
     if (!identical(x[[i]], quote(expr=))) walk(x[[i]])
   }
 }
 walk(tree); out
}
source_loop <- Filter(function(x) is.call(x) && identical(x[[1]],as.name("for")) &&
  identical(x[[2]],as.name("cell")) && identical(x[[3]],quote(names(cells))),nested_calls(main_assignment))[[1]]
evaluator <- Filter(function(x) is.call(x) && identical(x[[1]],as.name("<-")) &&
  identical(x[[2]],as.name("evaluate")),as.list(source_loop[[4]]))[[1]]
v <- new.env(parent=.GlobalEnv); v$env <- new.env(parent=.GlobalEnv)
v$cells <- list(first="runif(1); stop('fixture error')",second="value <- runif(1)")
v$cell <- "first"; v$stage <- "first"; v$state <- list(stages=list(first=list(),second=list()))
v$seed <- function() get(".Random.seed",.GlobalEnv); v$last_source_seed <- NULL
eval(evaluator,v)
set.seed(2024); reference <- runif(2)
set.seed(2024)
r <- ml_run_branch(v$evaluate,function() NULL,close_devices=function() NULL)
stopifnot(r$status=="training_failed",identical(v$last_source_seed,.Random.seed))
v$cell <- "second"; v$stage <- "second"
r <- ml_run_branch(v$evaluate,function() NULL,close_devices=function() NULL)
stopifnot(r$status=="succeeded",identical(v$env$value,reference[2]),
 identical(v$state$stages$second$rng_after_source,.Random.seed))
cat("PASS actual evaluator: failed-source RNG captured and continued into next synthetic branch\n")
