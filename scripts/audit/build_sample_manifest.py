import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

root = Path(__file__).resolve().parents[2]
metadata_path = root / "Data/Processed/metadata.csv"

with metadata_path.open(newline="") as f:
    reader = csv.DictReader(f)
    id_column = reader.fieldnames[0]
    metadata = {}
    for row in reader:
        sample = row[id_column].strip()
        if not sample or sample in metadata:
            raise ValueError(f"Empty or duplicate metadata ID: {sample}")
        metadata[sample] = row

records = []
seen = set()
source_hashes = {}

for dataset in ("GSE243375", "GSE52194", "GSE58135", "GSE263089"):
    path = root / f"Data/Raw/{dataset}/{dataset}_series_matrix.txt"
    if not path.exists():
        raise FileNotFoundError(path)

    source_hashes[str(path.relative_to(root))] = hashlib.sha256(
        path.read_bytes()
    ).hexdigest()

    fields = defaultdict(list)
    with path.open(newline="") as f:
        for line in f:
            if line.startswith("!Sample_"):
                parts = next(csv.reader([line], delimiter="\t"))
                fields[parts[0]].append(parts[1:])

    accession_rows = fields["!Sample_geo_accession"]
    if len(accession_rows) != 1:
        raise ValueError(f"{dataset}: expected one accession row")
    samples = accession_rows[0]

    for key, rows in fields.items():
        for values in rows:
            if len(values) != len(samples):
                raise ValueError(f"{dataset}: inconsistent length for {key}")

    def field(key, index):
        rows = fields.get(key, [])
        return rows[0][index] if rows else ""

    for index, sample in enumerate(samples):
        if sample in seen:
            raise ValueError(f"Duplicate source accession: {sample}")
        seen.add(sample)

        annotations = defaultdict(list)
        raw_annotations = []
        for values in fields.get("!Sample_characteristics_ch1", []):
            value = values[index]
            raw_annotations.append(value)
            key, separator, text = value.partition(":")
            if separator:
                annotations[key.strip().lower()].append(text.strip())

        def characteristic(key):
            return " | ".join(annotations.get(key, []))

        analytical = metadata.get(sample)
        patient = characteristic("patient id")
        included = analytical is not None

        records.append({
            "sample_id": sample,
            "dataset": dataset,
            "included_in_final_metadata": included,
            "analytical_label": analytical["category"] if included else "",
            "batch_alias": analytical["batch"] if included else "",
            "source_title": field("!Sample_title", index),
            "source_name": field("!Sample_source_name_ch1", index),
            "tissue": characteristic("tissue"),
            "disease_state": characteristic("disease state"),
            "tumor_type": characteristic("tumor type"),
            "treatment": characteristic("treatment"),
            "patient_id": patient,
            "patient_group_id": f"{dataset}:{patient}" if patient else "",
            "patient_id_status": "reported" if patient else "not_reported",
            "historical_exclusion_reason": "" if included else "unknown",
            "raw_characteristics": json.dumps(raw_annotations, ensure_ascii=False),
            "source_file": str(path.relative_to(root)),
            "source_sha256": source_hashes[str(path.relative_to(root))],
        })

unmatched = set(metadata) - seen
if unmatched:
    raise ValueError(f"Metadata samples absent from sources: {sorted(unmatched)}")

output = root / "Data/Manifests/sample_provenance.csv"
output.parent.mkdir(parents=True, exist_ok=True)
with output.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=list(records[0]))
    writer.writeheader()
    writer.writerows(records)

print("Saved:", output.relative_to(root))
print("Source samples:", len(records))
print("Included samples:", sum(r["included_in_final_metadata"] for r in records))
print("\nIncluded samples by dataset and label:")
counts = Counter(
    (r["dataset"], r["analytical_label"])
    for r in records if r["included_in_final_metadata"]
)
for group, count in sorted(counts.items()):
    print(*group, count)

selected = [
    r for r in records
    if r["dataset"] == "GSE243375" and r["included_in_final_metadata"]
]
patients = Counter(r["patient_group_id"] for r in selected if r["patient_group_id"])
print("\nGSE243375 treatment:", dict(Counter(r["treatment"] for r in selected)))
print("GSE243375 patients with reported IDs:", len(patients))
print("Samples per patient:", dict(sorted(Counter(patients.values()).items())))
print("Included samples without patient IDs:",
      sum(not r["patient_id"] for r in records if r["included_in_final_metadata"]))
