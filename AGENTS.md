# Project instructions

## Goal
Reproduce the original breast-cancer transcriptomics analysis, then
correct and validate its methodology before making publication claims.

## Roles
- ChatGPT: project management, scientific decisions, progress tracking.
- Codex: implement the explicitly assigned task and run relevant checks.
- Claude Code: review changes for correctness, reproducibility,
  scientific validity, and scope.
- Samuel: run local commands and approve scientific scope changes.

## Scope and workflow
- Work on analysis/initial-review unless instructed otherwise.
- Inspect existing files before editing.
- Complete one bounded task at a time.
- Do not introduce additional analyses or restructure unrelated files.
- Keep baseline reproduction separate from methodological corrections.
- Report changed files, commands run, results, and remaining limitations.
- Do not commit, push, or merge unless explicitly instructed.
- Never claim checks passed unless they were actually run.

## Preserve provenance
- Do not modify Data/Raw/ or notebooks/original/.
- Do not overwrite existing processed inputs or historical results.
- Write new generated outputs to a separate, clearly named location.
- Preserve sample and gene identifiers; check alignment explicitly.
- Document input paths, checksums, parameters, and software versions.
- Never invent historical processing or exclusion reasons.

## Established baseline
- Count matrix: Data/Processed/updated_count_matrix (1).csv
- Dimensions: 39,376 gene rows and 279 sample columns.
- SHA-256:
  5e2b722f8f72d8421069e1bbef693389bb863bf7731553e98b3344693c41fd0d
- Metadata: Data/Processed/metadata.csv
- Sample manifest: Data/Manifests/sample_provenance.csv
- Analytical datasets: GSE243375, GSE52194, GSE58135.
- GSE263089 has no samples in the final metadata.
- The earlier 31,001-row attachment was truncated, not a filtered version.
- R and Rscript 4.5.2 are installed; renv is not yet initialized.

## Scientific safeguards
- Historical saved outputs are not newly reproduced results.
- Record baseline discrepancies instead of silently correcting them.
- Gene-annotation provenance remains unresolved.
- Dataset and analytical label are strongly confounded.
- GSE243375 includes 158 pretreatment samples from 95 patients.
- Missing patient IDs do not establish independent patients.
- Corrected ML must keep each known patient within one evaluation group.
- Corrected predictive evaluation must prevent feature-selection leakage.
- Do not interpret original ML scores as independent validation.
- The historical 156-versus-158 detail is parked unless it becomes
  necessary for an explicitly assigned task.

## Environment
- Use a project-local renv environment for R packages.
- Avoid global package installation or environment changes unless assigned.
- Do not add credentials or Windows Zone.Identifier files to Git.
