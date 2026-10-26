# Project_RNASeq_BreastCancer

Faithful baseline reproduction and its limitations are kept separate from future
methodological corrections. Reproduced classifier scores are not independent
clinical validation.

The baseline RC entry point verifies **frozen archived evidence only**:

```sh
python3 scripts/release/verify_frozen_evidence.py Results/baseline_release/rc1
```

Requires Python 3.11+ and base R/Rscript 4.5.2; no installation, training or network
access occurs. Supply the actual preserved bundle directory if relocated.
Large evidence is not in Git and no public download location is established.
See [RC layout, accepted dispositions, patient audit and archival requirements](docs/baseline-release-candidate.md).
The trusted index is [release/baseline-rc1/evidence-manifest.json](release/baseline-rc1/evidence-manifest.json).

This does **not** establish a clean-clone end-to-end rebuild, all-stage success
or scientific validation. Original WGCNA remains incomplete, Manu ML has a
finalised LR failure, and manuscript ML retains probability-alignment defects.
[Stage replay instructions](docs/baseline-stage-replay.md) require separate
authorisation and are never called by the frozen verifier.

See [claim reconciliation](docs/baseline-result-reconciliation.md),
[release inventory](docs/baseline-release-inventory.md) and the RC's finite
checklist. No commit, push, tag, deletion or publication is authorised by verification.
