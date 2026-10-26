#!/usr/bin/env python3
"""Exact manuscript source and bounded wrapper checks; no runner execution."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
root = Path(__file__).resolve().parents[2]
notebook = Path('/home/samuel/wgcna-evidence-20261024/manuscript-reconciliation-inputs/Machine_Learn.ipynb')
assert hashlib.sha256(notebook.read_bytes()).hexdigest() == '24f7b02dd302afc48d695fdf7cb6b26968edd6b4b63212c28d33d2a3c6f6c1a1'
n = json.loads(notebook.read_text())['cells']
s = (root/'scripts/baseline/manuscript-ml.R').read_text()
blocks = re.findall(r'`(\d+)` = r"---\((.*?)\)---"', s, re.S)
assert [int(i) for i, _ in blocks] == [69,70,71,72,73,74,8,13,20,28]
for number, text in blocks:
    assert text == ''.join(n[int(number)-1]['source']), number
    assert hashlib.sha256(text.encode()).hexdigest() in s, number
assert hashlib.sha256(''.join(n[67]['source']).encode()).hexdigest() in s
wrapper = s[:s.index('cell_hashes <- c(')]
assert s.count('set.seed(2024)') == 1
assert 'set.seed(' not in wrapper and 'install.packages(' not in wrapper
assert 'env <- .GlobalEnv' in wrapper
assert 'as.data.frame(expr, optional = TRUE)' in wrapper
assert 'manuscript_category_bridge(metadata, rownames(expr))' in wrapper
assert 'ml_assert_rng(last_source_seed, seed())' in wrapper
assert 'manuscript_check_xgboost_review' in wrapper
assert 'file.path("faithful", paste0(label' in wrapper
assert 'file.path("diagnostics", paste0(label' in wrapper
assert 'Results/baseline_manuscript_ml' in wrapper
assert '/Results/baseline_manuscript_ml/' in (root/'.gitignore').read_text().splitlines()
assert wrapper.index('graphics.off()') < wrapper.index('write.csv(manifest,')
assert wrapper.index('close_log()\n    paths <-') < wrapper.index('write.csv(manifest,')
assert wrapper.index('"Manifest read-back failed"') < wrapper.index('atomic("review-finalization.json"')
# Existing implementation/infrastructure and all baseline lock/bootstrap bytes unchanged.
for name in ['scripts/baseline/ml.R','scripts/baseline/ml-support.R',
             'scripts/baseline/ml-dependency-plan.R','renv.lock','renv/settings.json','renv/activate.R','.Rprofile']:
    assert (root/name).read_bytes() == subprocess.check_output(['git','show','HEAD:'+name],cwd=root), name
print('PASS: ten exact blocks/11 cell pins, sole source seed, isolated outputs/diagnostics, finalisation order, original baseline files unchanged')
