#!/usr/bin/env python3
"""Source/static checks only: never imports R or executes the runner."""
import hashlib
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
notebook = root / 'notebooks/original/Original_Manu_Pipe.ipynb'
assert hashlib.sha256(notebook.read_bytes()).hexdigest() == 'ca9671af2eb21bf551641d1e01bfebef5926c1547fee60c86e6bc06caff2f45c'
cells = json.loads(notebook.read_text())['cells']
runner = (root / 'scripts/baseline/ml.R').read_text()
blocks = re.findall(r'`(\d+)` = r"---\((.*?)\)---"', runner, flags=re.S)
assert [int(i) for i, _ in blocks] == [55, 57, 58, 59, 60]
for number, text in blocks:
    source = ''.join(cells[int(number)-1]['source'])
    specification = (root / 'docs/baseline-ml-reproduction-spec.md').read_text()
    assert hashlib.sha256(source.encode()).hexdigest() in specification
    expected = ''.join(line for line in source.splitlines(keepends=True)
                       if not line.startswith('install.packages('))
    assert text == expected, number
assert runner.count('set.seed(2024)') == 3  # cells 57, 59, 60; never before RF
wrapper = runner[:runner.index('cells <- list(')]
assert 'install.packages' not in wrapper
assert 'set.seed(' not in wrapper
assert 'env <- .GlobalEnv' in wrapper
assert 'ml_probability_matrix(probability, samples, levels(truth))' in wrapper
assert 'ml_auc_matches(recomputed)' in wrapper
assert 'ml_assert_rng(state$stages$cell_57$rng_after_source, seed())' in wrapper
assert 'c("Mersenne-Twister", "Inversion", "Rejection")' in wrapper
assert 'ml_run_branch(evaluate, validate' in wrapper
assert 'ml_run_preparation(evaluate, validate)' in wrapper
assert wrapper.index('saveRDS(defaults, "effective_defaults.rds")') < wrapper.index('for (cell in names(cells))')
assert wrapper.index('graphics.off()') < wrapper.index('write.csv(manifest,')
assert wrapper.index('close_log()\n    paths <-') < wrapper.index('write.csv(manifest,')
assert wrapper.index('"Manifest read-back failed"') < wrapper.index('atomic("review-finalization.json"')
assert '"COMPLETED"' not in runner
assert '/Results/baseline_ml/' in (root / '.gitignore').read_text().splitlines()
print('PASS: five exact source blocks; seed placement; no wrapper installs/seeds; finalisation order; isolated output rule')
