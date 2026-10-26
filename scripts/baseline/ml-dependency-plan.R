#!/usr/bin/env Rscript
# Offline planner: pure resolution is fixture-testable; CLI never installs.
ml_resolve_dependencies <- function(metadata, versions, base_versions,
                                    r_version = as.character(getRversion())) {
  stopifnot(is.matrix(metadata),
    all(c("Package", "Version", "Depends", "Imports", "LinkingTo") %in% colnames(metadata)),
    !anyDuplicated(rownames(metadata)))
  base_names <- names(base_versions)
  selected <- character()
  requirements <- list()
  queue <- c("randomForest", "caret", "pROC", "e1071")
  parse_deps <- function(text, parent) {
    if (is.na(text) || !nzchar(trimws(text))) return()
    for (entry in strsplit(text, ",", fixed = TRUE)[[1]]) {
      entry <- trimws(entry)
      hit <- regmatches(entry, regexec("^([A-Za-z][A-Za-z0-9.]*)[[:space:]]*(\\(([<>=!]+)[[:space:]]*([^ )]+)\\))?$", entry))[[1]]
      if (!length(hit)) stop("Unparsed dependency: ", entry)
      p <- hit[2]; op <- hit[4]; requested <- hit[5]
      requirements[[length(requirements) + 1L]] <<- list(parent = parent, package = p, operator = op, version = requested)
      if (p == "R") actual <- r_version else if (p %in% names(versions)) actual <- versions[[p]] else {
        if (!p %in% rownames(metadata) && !p %in% base_names) stop("Unavailable dependency: ", p)
        actual <- if (p %in% base_names) base_versions[[p]] else metadata[p, "Version"]
      }
      if (nzchar(op)) {
        cmp <- utils::compareVersion(actual, requested)
        ok <- switch(op, `>=` = cmp >= 0, `>` = cmp > 0, `<=` = cmp <= 0,
          `<` = cmp < 0, `==` = cmp == 0, `!=` = cmp != 0, FALSE)
        if (!ok) stop("Dependency conflict: ", parent, " requires ", entry, "; retained/selected ", actual)
      }
      if (p != "R" && !p %in% c(names(versions), base_names, names(selected))) queue <<- c(queue, p)
    }
  }
  while (length(queue)) {
    p <- queue[1]; queue <- queue[-1]
    if (p %in% c(names(versions), names(selected), base_names)) next
    if (!p %in% rownames(metadata)) stop("Package absent from reviewed metadata: ", p)
    selected[p] <- metadata[p, "Version"]
    for (field in c("Depends", "Imports", "LinkingTo")) parse_deps(metadata[p, field], p)
  }
  list(additions = selected, requirements = requirements)
}
ml_dependency_main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Arguments: CRAN_PACKAGES_METADATA.rds NEW_PLAN_DIRECTORY")
  if (!file.exists("AGENTS.md") || !file.exists("renv.lock")) stop("Run from repository root")
  metadata <- readRDS(args[1])
  lock <- renv::lockfile_read("renv.lock")
  stopifnot(length(lock$Packages) == 113L)
  versions <- vapply(lock$Packages, function(x) x$Version, "")
  base <- installed.packages(lib.loc = .Library)
  base <- base[which(base[, "Priority"] == "base"), , drop = FALSE]
  resolved <- ml_resolve_dependencies(metadata, versions, setNames(base[, "Version"], rownames(base)))
  # Resolve before creating output; no baseline mutation even on conflict.
  if (file.exists(args[2]) || !dir.create(args[2], recursive = FALSE)) stop("Plan directory must be new")
  plan <- c(list(baseline_lock_sha256 = digest::digest(file = "renv.lock", algo = "sha256"),
    metadata_sha256 = digest::digest(file = args[1], algo = "sha256")), resolved,
    list(note = "Prospective source versions, NOT historical versions or an executable lock. No packages changed."))
  saveRDS(plan, file.path(args[2], "dependency-plan.rds"))
  write.csv(data.frame(Package = names(resolved$additions), Version = unname(resolved$additions)),
    file.path(args[2], "additions.csv"), row.names = FALSE)
  writeLines(capture.output(str(plan)), file.path(args[2], "dependency-plan.txt"))
}
ml_dependency_main()
