# Read-only saved-ID export; no runner, model, package load or split recomputation.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L, !file.exists(args[3]))
rows <- list()
for (i in 1:2) {
  split <- readRDS(args[i])
  for (partition in c("train", "test")) {
    ids <- split[[paste0(partition, "_samples")]]
    stopifnot(is.character(ids), length(ids) > 0L, !anyNA(ids),
      !anyDuplicated(ids), all(nzchar(ids)), identical(trimws(ids), ids))
    rows[[length(rows)+1L]] <- data.frame(run=c("M1","R1")[i], partition=partition,
      position=seq_along(ids), sample_id=ids, stringsAsFactors=FALSE)
  }
}
write.csv(do.call(rbind,rows), args[3], row.names=FALSE)
