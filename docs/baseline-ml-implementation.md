# Faithful ML implementation handoff

This is an unexecuted ML runner for Claude review, not a validated result.
Preprocessing/WGCNA code, notebooks, inputs, the 113-package baseline lock,
settings and activation files remain unchanged. No package was installed and
no model was fitted in preparing this revision.

## B1–B4 and branch policy

- Notebook cells evaluate in `.GlobalEnv`; wrapper state/helpers remain local
  to main(). Formula terms therefore reference the notebook environment rather
  than serializing the wrapper frame or a child environment. Fitted model objects
  are read back with an environment-free comparison (`ml_environment_free`):
  every value, attribute, call and formula text is compared exactly, but captured
  environments are placeholders. This is required because caret 7.0-1's multinom
  fit builds `.outcome ~ .` inside its fit function, so `finalModel$terms` holds
  that call frame. Predictions, probabilities, truth, confusion matrices, AUCs and
  other saved outputs stay strictly identical(); evidence RDS and source RData
  SHA-256 values are recorded. Saved models are never stripped or modified.
- Probability matrices and numeric data frames are accepted. A matrix copy is
  used only for validation/recomputed metrics; the original object is retained.
  Dimensions, unique class labels, sample row alignment, finiteness, range and
  row sums are checked. Prediction names, where present, must match sample order.
- Failure in preparation (55) or split (57) stops analysis; all model branches
  remain not_reached. Otherwise 58, 59 and 60 are attempted in source order even
  after another model fails. Branches record training_status, validation_status
  and errors with phases, plus status succeeded/training_failed/validation_failed.
  A source-cell error is training_failed (it may arise in fitting, prediction,
  plotting or source saving); it does not prove that fitting itself failed.
  Validation or graphics cleanup failure is validation_failed. Graphics close
  after each model branch, on success or failure. Global finalisation failures
  remain wrapper failures. This policy is now explicit in specification §7/§9.
- AUC checkpoint agreement uses seven significant digits. In particular 0.9996
  differs from the printed historical 1. Historical probabilities and split IDs
  are unavailable, so agreement is limited to the available printed checkpoint.

Cells 55, 57, 58, 59, 60 remain verbatim except the two install statements.
Source hashes, the pinned five inputs, name mapping, sample/factor/panel order,
bridge CSV/RDS read-back and isolated source-model read-backs are checked.
Missing genes and ambiguous make.names results stop preparation without repair.
All outputs go into a new ignored Results/baseline_ml/run-* directory.

The runner asserts RNGkind() = Mersenne-Twister / Inversion / Rejection without
changing it, and checks the saved post-split RNG state immediately before RF.
Namespaces/defaults load before cell 57's seed reset. No added seed precedes RF;
SVM and logistic retain their own resets. The global evaluation environment does
not make wrapper locals visible to notebook function lookup. No parallel backend
is registered. Explicit source printing remains; eval() does not auto-print
bare return values. Original messages go to execution.log, with flushed labelled
copies through stdout. SIGKILL/host loss can interrupt logs/finalisation.

Graphics and logs close before hashing; the manifest is independently re-read
and checked. review-finalization.json, excluded from the manifest, is an audit
record, never COMPLETED. Exit 0 means all models internally verified; 3 means
finalised evidence with preparation/training/validation failure; 2 preflight
blocked; 1 wrapper/finalisation/integrity failure. Early argument/path/tree errors
may exit 1 before a run directory exists. Branch details remain in provenance;
the final record lists failed stages and model statuses. Historical agreement is
separate from all exit/status classifications.

Historical error equivalence is **manual review**: inspect captured caret
per-resample diagnostics and relevant nnet code before identifying a cause.
The runner leaves failure_comparison not_verifiable. Generic Stopping alone is
insufficient. Unknown historical package versions and SVM probability RNG
repeatability are documented limitations, not blockers to one faithful execution
and not grounds to add fits, seed resets or fitting-limit repairs.

## One dependency preparation procedure (proposed, not run)

Execution still needs four direct additions (randomForest, caret, pROC, e1071)
and their required transitive closure. nnet stays at baseline 7.3-20. Exact added
versions are unresolved until metadata is captured. The alternate-session
randomForest 4.7-1.2 message is historical evidence only. Use this single route:

1. After separate authorisation for dependency preparation, create a new
   `$HOME/env-records/ml-dependencies-<UTC>-<PID>` directory (PREP below), set
   `REPO` to this repository and `LIB` to its renv project library. Work from REPO
   with R 4.5.2 and activated renv 1.3.1. Record hashes of renv.lock,
   renv/settings.json, renv/activate.R and .Rprofile before doing anything else;
   record sessionInfo and the 113 project-library DESCRIPTION versions/paths.
   Require baseline versions and paths to pass the existing runner checks.
2. Capture **one dated source CRAN metadata matrix**, with the exact origin
   recorded, then freeze it and its hash. This is a dated metadata snapshot,
   not a claim that the live CRAN URL is immutable:

   ```r
   # Proposed future R code from the activated project; PREP must already exist.
   prep <- Sys.getenv("PREP"); stopifnot(dir.exists(prep))
   repository <- "https://cloud.r-project.org"
   ap <- available.packages(repos = c(CRAN = repository), type = "source")
   saveRDS(ap, file.path(prep, "CRAN-PACKAGES.rds"))
   saveRDS(list(repository = repository, captured_utc = format(Sys.time(), tz = "UTC"),
     R = R.version, session = sessionInfo()), file.path(prep, "metadata-origin.rds"))
   ```

   Run `Rscript scripts/baseline/ml-dependency-plan.R "$PREP/CRAN-PACKAGES.rds" "$PREP/plan"`.
   The offline planner resolves Depends/Imports/LinkingTo, excludes Suggests,
   preserves all baseline versions and fails on conflicts. Recommended packages
   absent from the baseline lock (for example MASS/class/nlme) are additions
   requiring explicit project-library installation, not silent sandbox fallback.
   The resolver cannot backtrack to archived versions or prove build support.
   A conflict stops this procedure for review; never upgrade baseline records.
3. Download only the planned source versions, using the saved matrix as the
   `available` argument of `utils::download.packages(..., type="source")`.
   Require exactly one tarball per planned addition. Inspect each DESCRIPTION
   for exact Package/Version, required dependency constraints, repository origin
   and SystemRequirements; hash every tarball. Review the metadata, addition list,
   source hashes and native build requirements before installation is authorised.
   Source inspection of RNG is useful provenance, but unresolved SVM probability
   RNG repeatability must be labelled unknown rather than blocking one run.
4. Once that exact plan is approved, install only those local tarballs into LIB
   in dependency order, with `utils::install.packages(tarball, lib=LIB, repos=NULL,
   type="source", dependencies=FALSE)`. Determine the order from the planner's
   requirements: all added dependencies of a package must already be installed;
   fail if no package is ready. Never use automatic dependency installation.
   Save stdout/stderr/build logs and stop on a package error or version/path
   mismatch. Baseline packages are not install targets. Record final DESCRIPTION
   versions and resolved paths for every baseline and addition, and check all
   planned requirements, including those against R and retained versions.
5. Produce a **separate** ML lock, without snapshotting into renv.lock. This
   proposed R block shows the exact record-preserving merge; it must run only
   after approved installation and version/path verification:

   ```r
   prep <- Sys.getenv("PREP"); stopifnot(dir.exists(prep))
   baseline <- renv::lockfile_read("renv.lock")
   plan <- readRDS(file.path(prep, "plan", "dependency-plan.rds"))
   stopifnot(length(baseline$Packages) == 113L,
     identical(digest::digest(file="renv.lock", algo="sha256"), plan$baseline_lock_sha256))
   added <- names(plan$additions)
   stopifnot(!any(added %in% names(baseline$Packages)))
   candidate_path <- file.path(prep, "installed-additions.lock")
   extension_path <- file.path(prep, "ml-renv.lock")
   stopifnot(!file.exists(candidate_path), !file.exists(extension_path))
   renv::snapshot(lockfile=candidate_path, packages=added, prompt=FALSE)
   candidate <- renv::lockfile_read(candidate_path)
   stopifnot(all(added %in% names(candidate$Packages)),
     identical(unname(vapply(candidate$Packages[added], function(x) x$Version, "")),
       unname(plan$additions)))
   extension <- baseline
   extension$Packages <- c(baseline$Packages, candidate$Packages[added])
   renv::lockfile_write(extension, file=extension_path)
   checked <- renv::lockfile_read(extension_path)
   stopifnot(identical(checked$R, baseline$R),
     identical(checked$Bioconductor, baseline$Bioconductor),
     setequal(names(checked$Packages), c(names(baseline$Packages), added)))
   for (p in names(baseline$Packages))
     stopifnot(identical(checked$Packages[[p]], baseline$Packages[[p]]))
   ```

   The installed renv 1.3.1 snapshot/lockfile_write signatures were inspected
   locally; this block itself was not run. Snapshot records the approved additions;
   only their selected records enter the extension. All baseline records and
   R/repository/Bioconductor metadata come from the unchanged baseline lock.
   Review any source/Repository fields for restoration support; do not assume
   a locally installed archive automatically yields a portable source record.
6. Verify the four protected-file hashes against step 1, clean Git state, all
   extension DESCRIPTION versions and resolved project paths (the runner repeats
   these checks). Hash and retain the separate extension, metadata, tarballs,
   plan, logs and checks outside baseline evidence. Claude reviews this bundle
   and the implementation before a single training command is authorised.

No dependency metadata download, installation, snapshot or lock generation was
performed during this code revision. The lock extension does not yet exist.
Existing renv::status may report missing ML dependencies from static source
scanning; do not resolve that by changing the baseline lock. Existing baseline
runners check their own retained versions; additions must not replace them.

## Future execution and checks

After dependency and implementation approval, the command shape is:

```sh
Rscript scripts/baseline/ml.R VERIFIED_PANEL_DIRECTORY REVIEWED_ML_LOCKFILE
```

The known candidate panel directory is
`/home/samuel/wgcna-evidence-20261024/baseline-review/baseline`.
No execution is authorised by this handoff. Full-cohort selection/preprocessing,
study/category confounding, ungrouped splits and test-selected ROC direction
remain leakage/scientific limitations; this is not independent validation.

Run the bounded non-training checks with:

```sh
python3 tests/static/check_baseline_ml.py
Rscript --vanilla tests/runtime/check_baseline_ml.R
```

Runtime fixtures use base-R formula/terms objects (not fitted models), RDS/RData
read-backs, synthetic probabilities, branch callbacks/errors, a small PDF device,
RNG-state values and synthetic dependency metadata/conflicts. They evaluate the
actual helper functions and selected main assignments, never main() or notebook
model cells. They do not establish actual caret/RF/SVM fit behaviour, hidden
native RNG behaviour, package builds or complete live-run finalisation.

### Results of this revision's checks

Both ML scripts, the support helper and runtime fixture file parse successfully.
The existing source/static checker passes with all five source blocks unchanged.
All seven runtime fixture groups passed, including the nested-formula read-back
group. Nine single-guard mutations on temporary copies were rejected: child
formula environment, matrix-only probabilities, branch error rethrow,
three-decimal AUC matching, disabled RNG continuity check, disabled
dependency-conflict check, whole-object identical() model read-back, ignored
attributes in the environment-free view and an uncompared evidence model. Git
tracked/staged whitespace checks and explicit whitespace checks on all new files
pass. These code checks ran no runner/main or model training; dependency
preparation was performed separately under
`$HOME/env-records/ml-dependencies-20261026T071424Z-77321/`.
