# Stage replay is separate from frozen-evidence verification

These are historical/proposed stage commands, **not** release-verifier actions
and not authorised by release verification. No analysis was rerun for RC1.
Consult AGENTS.md and each stage specification before separately approving a run.

1. Baseline preprocessing: `Rscript scripts/baseline/preprocess.R` with unchanged
   113-package renv.lock/R4.5.2/Bioconductor3.21 restoration. See
   [preprocessing](baseline_preprocessing.md). A new run gets a new directory;
   do not overwrite the saved bridge or assume bitwise historical identity.
2. WGCNA: `Rscript scripts/baseline/wgcna.R` on a separately reviewed >=60GiB
   guest/cgroup environment, reference BLAS and dedicated external monitoring.
   See [WGCNA](baseline_wgcna.md) and archived monitoring/retrieval READMEs.
   It uses the pinned original preprocessing run name/hash and does not consume
   an arbitrary newly created preprocessing run. The original attempt remains
   incomplete; RC acceptance requires no rerun to change that disposition.
3. Manu ML: fresh `Rscript scripts/baseline/ml.R PANEL_DIRECTORY MANU_LOCKFILE`.
   The preserved lock is release/baseline-rc1/environments/manu-renv.lock. See
   [ML handoff](baseline-ml-implementation.md). Its caret LR stopping outcome is
   not repaired. It uses the named pinned preprocessing bridge.
4. Manuscript ML: fresh process from repository root, no added seed resets:

   ```sh
   Rscript scripts/baseline/manuscript-ml.R \
     /ACTUAL/PATH/Machine_Learn.ipynb \
     /ACTUAL/PATH/VERIFIED_PANEL_DIRECTORY \
     release/baseline-rc1/environments/manuscript-renv.lock \
     release/baseline-rc1/environments/xgboost-api-review.json \
     release/baseline-rc1/environments/manu-renv.lock
   ```

   See [manuscript ML](baseline-manuscript-ml.md). Use actual preserved paths,
   separately restore the reviewed 150-record environment without replacing
   existing records, verify source/archive and build provenance, and obtain
   execution approval. The original full-precision bridge is still required.
   An API review is evidence, not a substitute for installing the exact version.

These stage commands require a clean reviewed checkout, appropriate environments,
verified inputs, resources and new output directories. No umbrella build command
or clean-clone chaining has been implemented. Restoration/source archives for
the 113-package base may need separately managed mirrors/build infrastructure;
Git locks alone do not guarantee future remote availability or native builds.
Do not call these commands to verify the release; use the Python frozen verifier.
